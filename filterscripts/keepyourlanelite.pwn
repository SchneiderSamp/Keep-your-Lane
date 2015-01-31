#include <a_samp>
#include <sscanf2>
#include <streamer>

//#define ALLOW_DRIVING_ON_TRAIN_TRACK    //While this define is diabled (commented) players are NOT allowed to drive on traintracks. Remove the // to allow players to drive on the tracks.



#define MAX_ROADPOINTS_PER_ZONE 500  // This value will define the size of the array in which the RoadPoints in each zone will be stored.
                                     // If this value is too small (there are more RoadPoints in a zone than this value) this system will be terminated.
                                     // On the other hand, if this value is too large your server will be less efficient. Keep an eye on the serverlog...
                                     // ...it will show you the ideal value based on the number of RoadPoints found.


#define ANGLE_TOLERANCE 25   // Example: if this value is set at 25 degrees and a given RoadPoint has an original angle of 150 degrees, the script will...
							 //          ...trigger OnPlayerWrongLane when a player passes this point with an angle between 125 and 175 degrees.


#define ROADPOINT_CHECK_INTERVAL 100   // This the interval in milliseconds of which the script will check each player if it's driving on the wrong side of the road.
	                         // The lower this value the more precice this system will work, but with many players or having a large script it might slow it down.


#define BUILD "2.1.1"

#if defined ALLOW_DRIVING_ON_TRAIN_TRACK
	new bool:AllowTrainTrackDriving = true;
#else
	new bool:AllowTrainTrackDriving = false;
#endif

//New Variables:
new TRP;  //Will store the total amout of RoadPoints created.  (wont get lowered when RoadPoints gets removed until restart. Used to give new Roadpoints an unique ID).

//Roadpoint Enum
enum rpinfo
{
	ID,      //Holds the unique ID of each RoadPoint
	Float:X,  // Holds the X coordinate of each RoadPoint
	Float:Y,  // Holds the Y coordinate of each RoadPoint
	Float:Z,  // Holds the Z coordinate of each RoadPoint
	Float:A,  // Holds the angle of each roadpoint (Note: this value should be the angle the players are supposed to drive!)
	Float:D,  // Holds the maximum distance a player has to be from this RoadPoint before it's triggered.
}

enum tpinfo
{
	Float:tpX,  // Holds the X coordinate of each RoadPoint
	Float:tpY,  // Holds the Y coordinate of each RoadPoint
	Float:tpZ,  // Holds the Z coordinate of each RoadPoint
	Float:tpD,  // Holds the maximum distance a player has to be from this RoadPoint before it's triggered.
}

//This is the main array that stores all info about each RoadPoint.
//The first dimention (37) is the number of zones (36 zones as described above + 1 extra zone in case players have custom roads build on the oceans around the map.
//Each zone has (MAX_ROADPOINTS_PER_ZONE) slots available.
new RP[145][MAX_ROADPOINTS_PER_ZONE][rpinfo];
new RPInZone[145];
new TP[145][90][tpinfo];
new TPInZone[145];

new CZ[MAX_PLAYERS];

//Publics
public OnFilterScriptInit()
{
    ResetRoadPointInfo(); //Will destroy and reset all values and pickups.
    new Float:minX, Float:maxX, Float:minY, Float:maxY;
	maxY = 3000.0;
	minY = 2500.0;
    for(new i; i<12; i++)
	{
	    minX = -3000.0;
	    maxX = -2500;
	    for(new j; j<12; j++)
	    {
	        CreateDynamicRectangle(minX, minY, maxX, maxY);
			minX = floatadd(minX, 500.0);
			maxX = floatadd(maxX, 500.0);
		}
		maxY = floatsub(maxY, 500.0);
		minY = floatsub(minY, 500.0);
	}
	print("\n--------------------------------------------");
	printf(" [FS]Keep Your Lane - Lite - Build %s", BUILD);
	print("            by Schneider 2014");
	print("---------------------------------------------\n");
	
	//This timer will trigger a function that will calculate the optimal value of MAX_ROADPOINTS_PER_ZONE...
	SetTimer("CheckEfficiency", 3000, 0);
	//SetTimer("SpeedTest", 4000, 0);
	SetTimer("CheckRoadPoints", ROADPOINT_CHECK_INTERVAL, 1);   //Start the main timer that checks each players position on the road.

	ReadRoadPoints(); // This function will read and load all RoadPoints from the KYLRoadPoints.txt file.

	if(AllowTrainTrackDriving == false)
	{
		ReadTrainPoints();
	}
	return 1;
}

public OnPlayerEnterDynamicArea(playerid, areaid)
{
	CZ[playerid] = (areaid-1);
	return 1;
}

public OnPlayerLeaveDynamicArea(playerid, areaid)
{
	if(CZ[playerid] == (areaid-1))
	{
	    CZ[playerid] = 144;
	}
	return 1;
}

stock GetZone(Float:vX, Float:vY)  // This function returns the zone-number based on given X- and Y-coord.
{
	for(new i=1; i<145; i++)
	{
		if(IsPointInDynamicArea(i, vX, vY, 0.0)) return (i-1); //Return the zone (0-143)
	}
	return 144; // Return oceanzone (144)
}

stock ResetRoadPointInfo()  // This Function will reset all RoadPoint-related variables and destroys the pickups.
{
    for(new zone; zone<145; zone++) // Loop through all 37 zones.
	{
	    for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)  // Loop through each slot in current zone
	    {
			RP[zone][slot][X] = 0.0;  //Reset X Coordinate
			RP[zone][slot][Y] = 0.0;  //Reset Y Coordinate
			RP[zone][slot][Z] = 0.0;  //Reset Z Coordinate
			RP[zone][slot][A] = 0.0;  //Reset Angle
			RP[zone][slot][D] = 0;  //Reset Max Distance
			RP[zone][slot][ID] = -1;  //Reset ID
		}
 	}
	return 1;
}

stock ReadRoadPoints() //  This function will read and load all RoadPoints from the KYLRoadPoints.txt file
{
	new File:file;
    if (!fexist("KYLRoadPoints.txt"))
    {
    	file = fopen("KYLRoadPoints.txt",io_write);
    	fclose(file);
	}
	file=fopen("KYLRoadPoints.txt", io_read);
	new str[64], zone, slot;  // Create new variables to store the string, zone and slot
	new Float:rX, Float:rY, Float:rZ, Float:rA, Float:rType; // Create new temprorarily variables to store the coordinates, angle and distance
 	while(fread(file, str))  // Loop through each line in the file
 	{
	 	sscanf(str, "fffff", rX, rY, rZ, rA, rType);  // Retrieve all values from the line and store them in the temporarily variables
  		{
  		    zone = GetZone(rX, rY);  // Get the zone ID based on the X and Y coordinate
  		    slot = GetFreeSlot(zone);  // Get the ID of the first free slot in this zone
  		    if(slot != -1)   // If there is an empty slot found
			{
	  		    RP[zone][slot][X] = rX;  // Store the temporarily X value in the global array
	  		    RP[zone][slot][Y] = rY;  // Store the temporarily Y value in the global array
	  		    RP[zone][slot][Z] = rZ;  // Store the temporarily Z value in the global array
	  		    RP[zone][slot][A] = rA;  // Store the temporarily angle in the global array
	  		    RP[zone][slot][D] = rType;  // Store the temporarily distance in the global array
	  		    RP[zone][slot][ID] = TRP; // Give the new RoadPoint an unique ID (based on total amount of created RoadPoints)
				TRP++;  // Increae number of total created RoadPoints by 1
				RPInZone[zone]++;
			}
			else  // if no empty slot is found in the current zone:
			{
			    //Send error message to the ServerLog
 				print("------------------------------------------------------------------");
				printf("FATAL ERROR: Too many RoadPoints in Zone #%02d (Limit: %d)", zone, MAX_ROADPOINTS_PER_ZONE);
				print("Loading of the RoadPoints has failed");
				print("Increase the value of MAX_ROADPOINTS_PER_ZONE");
				print("at the top of the filterscript and reload");
				print("------------------------------------------------------------------");
				ResetRoadPointInfo(); // Reset all RoadPoints related info.
				fclose(file); // Close the fille
				return 0; // Abort the function
			}
		}
	}
 	fclose(file);  // Close the file
 	printf("%d roadpoints loaded", TRP); // Show in ServerLog the total amound of created RoadPoints.
 	return 1;
}

stock ReadTrainPoints() //  This function will read and load all RoadPoints from the KYLRoadPoints.txt file
{
	new File:file;
    if (!fexist("KYLTrainRoadPoints.txt"))
    {
    	file = fopen("KYLTrainRoadPoints.txt",io_write);
    	fclose(file);
	}
	file=fopen("KYLTrainRoadPoints.txt", io_read);
	new str[64], zone, slot;  // Create new variables to store the string, zone and slot
	new Float:rX, Float:rY, Float:rZ, Float:rD; // Create new temprorarily variables to store the coordinates, angle and distance
 	while(fread(file, str))  // Loop through each line in the file
 	{
	 	sscanf(str, "ffff", rX, rY, rZ, rD);  // Retrieve all values from the line and store them in the temporarily variables
  		{
  		    zone = GetZone(rX, rY);  // Get the zone ID based on the X and Y coordinate
  		    slot = TPInZone[zone];
  		    if(slot != 90)   // If there is an empty slot found
			{
	  		    TP[zone][slot][tpX] = rX;  // Store the temporarily X value in the global array
	  		    TP[zone][slot][tpY] = rY;  // Store the temporarily Y value in the global array
	  		    TP[zone][slot][tpZ] = rZ;  // Store the temporarily Z value in the global array
	  		    TP[zone][slot][tpD] = rD-1.0;  // Store the temporarily distance in the global array
				TPInZone[zone]++;
			}
		}
	}
 	fclose(file);  // Close the file
 	return 1;
}

forward CheckRoadPoints();
public CheckRoadPoints()   // This is the main function that checks the players position and sees if he's driving on the wrong side of the road:
{
	new zone, slot, rtrn; // Create some variables to temporarily store values.
	for(new i; i<MAX_PLAYERS; i++) // Loop through all players
	{
	    if(IsPlayerConnected(i))
		{
			if(GetPlayerState(i) == PLAYER_STATE_DRIVER) // Check if the player is driving a vehicle
		    {
		        // My original plan was to only scan the players current zone for RoadPoints and check if the player is near any of them, but it caused problems when...
				//... because RoadPoints near its zone-border wont get triggered if the player is within reach, but on the other side of the border (in an different zone)...
				//... To solve this problem this script will not only scan the players current zone, but also the 4 surrounding zones for RoadPoints (if none have been found already).

				// I created the funtion 'IsPlayerOnWrongWay' to check if the player is near a Roadpoint and, if so, check if the player is driving the right or wrong direction.
				// It will return '-1' if the player is not near any roadpoint in the given zone. Return '0' if the player is near a RoadPoint, but driving the right direction...
				//..and it will return '1' if the player is near a RoadPoint AND driving the wrong direction.
				//... this function also returns the slot of the found RoadPoint.

			    rtrn = IsPlayerOnWrongWay(i, CZ[i], slot);   // Check if the player is near any RoadPoint in his current zone.
			    //// If the player is Ghost Driving, the remote callback 'OnPlayerGhostDriving' will be called (in your gamemode), it passes the playerid, zone, XYZ-coords and angle of the RoadPoint
				if(rtrn == 1) CallRemoteFunction("OnPlayerGhostDriving", "ddffff", i, zone, RP[CZ[i]][slot][X], RP[CZ[i]][slot][Y], RP[CZ[i]][slot][Z], RP[CZ[i]][slot][A]);
				else if(rtrn == -1)  // If no close RoadPoint is found... scan the next surrounding zone and repeat if for all 4 surrounding zones (unless a point is found.
				{
				    zone = CZ[i]+1;
				    rtrn = IsPlayerOnWrongWay(i, zone, slot);
				    if(rtrn == 1) CallRemoteFunction("OnPlayerGhostDriving", "ddffff", i, zone, RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z], RP[zone][slot][A]);
					else if(rtrn == -1)
					{
					    zone = CZ[i]-1;
					    rtrn = IsPlayerOnWrongWay(i, zone, slot);
					    if(rtrn == 1) CallRemoteFunction("OnPlayerGhostDriving", "ddffff", i, zone, RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z], RP[zone][slot][A]);
						else if(rtrn == -1)
						{
						    zone = CZ[i]+12;
						    rtrn = IsPlayerOnWrongWay(i, zone, slot);
						    if(rtrn == 1) CallRemoteFunction("OnPlayerGhostDriving", "ddffff", i, zone, RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z], RP[zone][slot][A]);
							else if(rtrn == -1)
							{
							    zone = CZ[i]-12;
							    rtrn = IsPlayerOnWrongWay(i, zone, slot);
							    if(rtrn == 1) CallRemoteFunction("OnPlayerGhostDriving", "ddffff", i, zone, RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z], RP[zone][slot][A]);
							}
						}
					}
				}
				if(AllowTrainTrackDriving == false)
				{
					new model = GetVehicleModel(GetPlayerVehicleID(i));
					if((model != 537) && (model !=538))
					{
						for(slot = 0; slot<90; slot++)  // Loop through all RoadPoints in the given zone
						{
					 		if(IsPlayerInRangeOfPoint(i, TP[CZ[i]][slot][tpD], TP[CZ[i]][slot][tpX], TP[CZ[i]][slot][tpY], TP[CZ[i]][slot][tpZ])) // Check if player is in range of the RoadPoint
						    {
						        CallRemoteFunction("OnPlayerDrivingOnTrainTrack", "ddfff", i, CZ[i], TP[CZ[i]][slot][tpX], TP[CZ[i]][slot][tpY], TP[CZ[i]][slot][tpZ]);
							}
						}
					}
				}
	        }
		}
	}
	return 1;
}

// This function will scan the given zone for RoadPoints and check if the given player is near them and driving in the right or wrong direction...
//.. it will return the slot of the Roadpoint in that zone and will return -1, 0, or 1, depending on if any points are found.
IsPlayerOnWrongWay(playerid, zone, &slot)
{
    new Float:cA, Float:MinAngle, Float:MaxAngle;
	new isfound = -1;  // On default no RoadPoint is found near the player
    for(slot = 0; slot<MAX_ROADPOINTS_PER_ZONE; slot++)  // Loop through all RoadPoints in the given zone
	{
 		if(IsPlayerInRangeOfPoint(playerid, RP[zone][slot][D], RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z])) // Check if player is in range of the RoadPoint
	    {
	        isfound = 0; // Set the variable to '0', this means the player is near a RoadPoint, now we should check if the player is driving the right/wrong direction:
			GetVehicleZAngle(GetPlayerVehicleID(playerid), cA);  // Get the current driving direction of the player
			cA = floatsub(cA, 180);  // Invert the direction by subtracting 180 degrees.
			if(cA < 0)  // check if the angle is below '0'
			{
				cA = floatadd(cA, 360.0);  // add 360 to get it above 0 degrees again.
			}
			MinAngle = floatsub(RP[zone][slot][A], ANGLE_TOLERANCE); // Calculate the minimum angle by subtracting the angle tolerance (defined at top of this script)
			MaxAngle = floatadd(RP[zone][slot][A], ANGLE_TOLERANCE); // Calculate the maximum angle by adding the angle tolerance (defined at top of this script)
			if((cA > MinAngle) && (cA < MaxAngle))  // Check if the players driving direction is between the mininmum and maximum angle (if yes, he's driving in the wrong direction)
			{
			    isfound = 1; // If the player is indeed Ghost Driving, set the varible to '1'.
 			}
        	break; // stop the loop.
		}
	}
	return isfound; // Return the result
}

stock GetFreeSlot(zone) // This funtion returns the ID of the first empty slot in the given zone. (Returns -1 if no empty slot is found in this zone).
{
	new freeslot = -1;
	for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)
	{
	    if(RP[zone][slot][ID] == -1)
	    {
			freeslot = slot;
			break;
		}
	}
	return freeslot;
}

stock GetLargestZone() // This function returns the zone ID which holds the most RoadPoints. (Used in the CheckEfficiency function).
{
	new largestzone = -1;
	new highestvalue = -1, tmp;
	for(new zone; zone<145; zone++)
	{
		tmp = GetFreeSlot(zone);
		if(tmp == -1)  //Zone is full
		{
			largestzone = zone;
			highestvalue = MAX_ROADPOINTS_PER_ZONE;
		}
		if(tmp > highestvalue)
		{
			largestzone = zone;
			highestvalue = tmp;
		}
	}
	return largestzone;
}

forward CheckEfficiency();
public CheckEfficiency() // This function will check if the defined value of MAX_ROADPOINTS_PER_ZONE is optimal
{
	new zone = GetLargestZone();  // Retreive the zone which holds the most RoadPoints
	new amount = GetFreeSlot(zone);  // Get the amount of RoadPoints in that zone.
	if((amount <= MAX_ROADPOINTS_PER_ZONE) && (amount > 1))  // Check if this amount is lower than the defined MAX_ROADPOINTS_PER_ZONE
	{
		// If so, send a message to the serverlog suggesting the optimal value:
	    print("------------------------------------------------------------------");
	    print("[TIP]: If you are done with creating new RoadPoints you can");
	    print("increase your server's performance by lowering the value");
		printf("of 'MAX_ROADPOINTS_PER_ZONE' to %d at the top of the Filterscript", amount);
		print("-------------------------------------------------------------------");
	}
	return 1;
}
