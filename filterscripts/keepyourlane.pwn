#include <a_samp>
#include <streamer>
#include <sscanf2>
#include <zcmd>
#include <vehiclematrix>

//#define ALLOW_DRIVING_ON_TRAIN_TRACK    //While this define is diabled (commented) players are NOT allowed to drive on traintracks. Remove the // to allow players to drive on the tracks.


#define MAX_ROADPOINTS_PER_ZONE 500  // This value will define the size of the array in which the RoadPoints in each zone will be stored.
                                     // If this value is too small (there are more RoadPoints in a zone than this value) this system will be terminated.
                                     // On the other hand, if this value is too large your server will be less efficient. Keep an eye on the serverlog...
                                     // ...it will show you the ideal value based on the number of RoadPoints found.


#define ANGLE_TOLERANCE 25   // Example: if this value is set at 25 degrees and a given RoadPoint has an original angle of 150 degrees, the script will...
							 //          ...trigger OnPlayerWrongLane when a player passes this point with an angle between 125 and 175 degrees.


#define ROADPOINT_CHECK_INTERVAL 100   // This the interval in milliseconds of which the script will check each player if it's driving on the wrong side of the road.
	                         // The lower this value the more precice this system will work, but with many players or having a large script it might slow it down.


#define BUILD "2.1.1 - Full Version (+Creator)"


#define TD_DARKRED -16777196
#define TD_BRIGHTGREEN 16711935
#define TD_BRIGHTRED 0xFF0000FF
#define TD_BLUE 0x0000FFFF

//New Variables:
new TRP;  //Will store the total amout of RoadPoints created.  (wont get lowered when RoadPoints gets removed until restart. Used to give new Roadpoints an unique ID).
new ATRP;  //This will store the actual total amount of RoadPoints (used for Textdraw)
new RPCreator = -1;   //Will store the playerid of the player who is creating new RoadPoints
new Float:RoadWidth = 2.5;  //Will store the type of RoadPoint during the creation of new RoadPoints (1 = normal road (1 lane) -- 2 = highway (2 lanes).
new Float:AutoCreateDistance = 20.0;  //Stores during AutoCreation the distance entered by the player. The new RoadPoints will be created with this distance from eachother.
new bool:IsCreating; // Bool to check if the AutoCreation-mode is enabled.
new bool:IsPauzed;   // Bool to check if the creation-mode is pauzed or not
new bool:Double;     // Bool to check if double of single directions are being made
new bool:IsDeleting;   //Bool to check if the creator is mass-deleting RoadPoints
new bool:ShowPresets;
new Float:lastX, Float:lastY, Float:lastZ;  //During AutoCreaton-mode a new RoadPoint will created at 'AutoCreateDistance' from these these X, Y and Z coordinates.
new Float:Space = 1.2;   // Stores the space between the 2 driving-directions during double-mode

#if defined ALLOW_DRIVING_ON_TRAIN_TRACK
	new bool:AllowTrainTrackDriving = true;
#else
	new bool:AllowTrainTrackDriving = false;
#endif

//Textdraws
new Text:Textdraw0;
new Text:Textdraw1;
new Text:Textdraw2;
new Text:Textdraw3;
new Text:Textdraw4;
new Text:Textdraw5;
new Text:Textdraw6;
new Text:Textdraw7;
new Text:Textdraw8;
new Text:Textdraw9;
new Text:Textdraw10;
new Text:Textdraw11;
new Text:Textdraw12;
new Text:Textdraw13;
new Text:Textdraw14;
new Text:Textdraw15;
new Text:Textdraw16;
new Text:Textdraw17;
new Text:Textdraw18;
new Text:Textdraw19;
new Text:Textdraw20;
new Text:Textdraw21;
new Text:Textdraw22;
new Text:Textdraw23;
new Text:Textdraw24;
new Text:Textdraw25;
new Text:Textdraw26;
new Text:Textdraw27;

//Textdraw-strings
new td2str[12] = "Pauzed";
new td5str[12] = "2.5";
new td10str[12] = "~g~0.0";
new td12str[12] = "~g~0";
new td15str[12] = "OFF";
new td19str[12] = "0.50";

//Preset TextDraw-strings
new pre1str[64] = "#1: Single - 0.00 - 0.00 - 0.00";
new pre2str[64] = "#2: Single - 0.00 - 0.00 - 0.00";
new pre3str[64] = "#3: Single - 0.00 - 0.00 - 0.00";
new pre4str[64] = "#4: Single - 0.00 - 0.00 - 0.00";
new pre5str[64] = "#5: Single - 0.00 - 0.00 - 0.00";

//Preset Enum
enum preinfo
{
	predouble,
	predoublestr[12],
	Float:prewidth,
	Float:predistance,
	Float:prespace
}
new Preset[5][preinfo];

//Roadpoint Enum
enum rpinfo
{
	ID,      //Holds the unique ID of each RoadPoint
	Float:X,  // Holds the X coordinate of each RoadPoint
	Float:Y,  // Holds the Y coordinate of each RoadPoint
	Float:Z,  // Holds the Z coordinate of each RoadPoint
	Float:A,  // Holds the angle of each roadpoint (Note: this value should be the angle the players are supposed to drive!)
	Float:D,  // Holds the maximum distance a player has to be from this RoadPoint before it's triggered.
	PickupID,  // Holds the pickupID that will be visible to the creator during the Creation-mode so you can see where you have already created RoadPoints.
	MapIconID
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
new TP[145][90][tpinfo];
new RPInZone[145];
new TPInZone[145];

new CZ[MAX_PLAYERS];

//Holds the Object-ids
new Object1;
new Object2;
new Object3;
new Object4;

//Publics
public OnFilterScriptInit()
{
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
    ResetRoadPointInfo(); //Will destroy and reset all values and pickups.
	LoadPresets();  // Load the presets from the file
	CreateTextDraws();  // Create the Textdraws

	print("\n--------------------------------------");
	printf(" [FS]Keep Your Lane - Build %s", BUILD);
	print("            by Schneider 2014");
	print("--------------------------------------\n");
	
	//This timer will trigger a function that will calculate the optimal value of MAX_ROADPOINTS_PER_ZONE...
	SetTimer("CheckEfficiency", 3000, 0);
	SetTimer("CheckRoadPoints", ROADPOINT_CHECK_INTERVAL, 1);   //Start the main timer that checks each players position on the road.

	ReadRoadPoints(); // This function will read and load all RoadPoints from the KYLRoadPoints.txt file.
	if(AllowTrainTrackDriving == false)
	{
		ReadTrainPoints();
	}
	return 1;
}

public OnFilterScriptExit()
{
    SavePresets();    // Save the presets to its file
    
	//Delete objects and textdraws
	if(IsValidDynamicObject(Object1)) DestroyDynamicObject(Object1);
    if(IsValidDynamicObject(Object2)) DestroyDynamicObject(Object2);
    if(IsValidDynamicObject(Object3)) DestroyDynamicObject(Object3);
    if(IsValidDynamicObject(Object4)) DestroyDynamicObject(Object4);
	TextDrawDestroy(Textdraw0);
	TextDrawDestroy(Textdraw1);
	TextDrawDestroy(Textdraw2);
	TextDrawDestroy(Textdraw3);
	TextDrawDestroy(Textdraw4);
	TextDrawDestroy(Textdraw5);
	TextDrawDestroy(Textdraw6);
	TextDrawDestroy(Textdraw7);
	TextDrawDestroy(Textdraw8);
	TextDrawDestroy(Textdraw9);
	TextDrawDestroy(Textdraw10);
	TextDrawDestroy(Textdraw11);
	TextDrawDestroy(Textdraw12);
	TextDrawDestroy(Textdraw13);
	TextDrawDestroy(Textdraw14);
	TextDrawDestroy(Textdraw15);
	TextDrawDestroy(Textdraw16);
	TextDrawDestroy(Textdraw17);
	TextDrawDestroy(Textdraw18);
	TextDrawDestroy(Textdraw19);
	TextDrawDestroy(Textdraw20);
	TextDrawDestroy(Textdraw21);
	TextDrawDestroy(Textdraw22);
	TextDrawDestroy(Textdraw23);
	TextDrawDestroy(Textdraw24);
	TextDrawDestroy(Textdraw25);
	TextDrawDestroy(Textdraw26);
	TextDrawDestroy(Textdraw27);

	// Delete the mapicons and pickups
    for(new zone; zone<145; zone++)
	{
	    for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)
	    {
	        if(IsValidDynamicPickup(RP[zone][slot][PickupID]))
			{
		    	DestroyDynamicPickup(RP[zone][slot][PickupID]);
				RP[zone][slot][PickupID] = -1;
			}
			if(IsValidDynamicMapIcon(RP[zone][slot][MapIconID]))
			{
			    DestroyDynamicMapIcon(RP[zone][slot][MapIconID]);
			    RP[zone][slot][MapIconID] = -1;
			}
		}
	}
	ResetRoadPointInfo(); //Will destroy and reset all values and pickups.
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if((RPCreator == playerid) && (oldstate == PLAYER_STATE_DRIVER) && (IsCreating == true))  //If RoadPoint-Creator is leaving his vehicle...
	{
	    IsCreating = false; //Disable the Creation-mode
	    RPCreator = -1;         //Reset the playerid of the RPCreator
	    IsPauzed = false;
	    IsDeleting = false;
		HideTextDraws(playerid);   //Hide the textdraws
		UpdateObjects(playerid, 1, -1);   //Delete the objects
		
		//Delete mapicons and pickups
	    for(new zone; zone<145; zone++)
		{
		    for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)
		    {
		        if(IsValidDynamicPickup(RP[zone][slot][PickupID]))
				{
			    	DestroyDynamicPickup(RP[zone][slot][PickupID]);
  					RP[zone][slot][PickupID] = -1;
				}
				if(IsValidDynamicMapIcon(RP[zone][slot][MapIconID]))
				{
				    DestroyDynamicMapIcon(RP[zone][slot][MapIconID]);
				    RP[zone][slot][MapIconID] = -1;
				}
			}
		}
		SendClientMessage(playerid, 0x00FF00AA, "RoadPoint-Creation Mode Disabled");
	}
	return 1;
}


public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
 	//DebugKeys(playerid, newkeys, oldkeys);
    if((RPCreator == playerid) && (GetPlayerState(playerid) == PLAYER_STATE_DRIVER))
    {
		if((newkeys & KEY_FIRE) && !(oldkeys & KEY_FIRE)) // Player presses left-mouse button >>> Select textdraw
		{
   		    SelectTextDraw(playerid, 0xFFFFFFFF);
		}
		if((newkeys & KEY_HANDBRAKE) && !(oldkeys & KEY_HANDBRAKE))  // Player presses Honk-key >>> Pauze/Activate Roadcreaton
		{
		    if(IsDeleting == true)  // If player is in mass-deleting-mode it will be disabled by pressing the handbrake
		    {
		        IsDeleting = false;
				IsPauzed = true;
				
			}
			else  // If the mode is either pauzed or enabled, then switch.
			{
				if(IsPauzed == false)
				{
				    IsPauzed = true;
				}
				else
				{
				    IsPauzed = false;
				}
			}
		}
		if ((newkeys & KEY_ACTION) && !(oldkeys & KEY_ACTION))  // Player Presses (Ctrl)  >>> Create new RoadPoint
		{
			new vid = GetPlayerVehicleID(playerid), Float:vX, Float:vY, Float:vZ, Float:vA;
			GetVehiclePos(vid, vX, vY, vZ);
			GetVehicleZAngle(vid, vA);
			new slot = GetFreeSlot(CZ[playerid]);
		    if(slot == -1)
		    {
		        SendClientMessage(playerid, 0xFF0000AA, "[Error] - The max amount of RoadPoints per zone has been reached!");
		        SendClientMessage(playerid, 0xFF0000AA, "Increae the MAX_ROADPOINTS_PER_ZONE define at the top of the filterscript and reload");
			}
			else
			{
				RP[CZ[playerid]][slot][X] = vX;
				RP[CZ[playerid]][slot][Y] = vY;
				RP[CZ[playerid]][slot][Z] = vZ;
				RP[CZ[playerid]][slot][A] = vA;
				RP[CZ[playerid]][slot][D] = floatdiv(RoadWidth, 2.0);
				RP[CZ[playerid]][slot][ID] = TRP;
				RP[CZ[playerid]][slot][PickupID] = CreateDynamicPickup(1318, 23, RP[CZ[playerid]][slot][X], RP[CZ[playerid]][slot][Y], RP[CZ[playerid]][slot][Z], -1, -1, playerid, 200.0);
                RP[CZ[playerid]][slot][MapIconID] = CreateDynamicMapIcon(RP[CZ[playerid]][slot][X], RP[CZ[playerid]][slot][Y], RP[CZ[playerid]][slot][Z], 56, 0, -1, -1, playerid, 300.0, MAPICON_LOCAL);
				TRP++;
				ATRP++;
				SaveRoadPoint(vX, vY, vZ, vA, RoadWidth);
			}
		}
		UpdateTextDraws(playerid);
	}
	return 1;
}


//This callback is used to automatically create new RoadPoints:
public OnPlayerUpdate(playerid)
{
    if((IsDeleting == true) && (RPCreator == playerid))
	{
		new slot = GetPlayerRoadPointSlot(playerid);
	    if(slot != -1)
		{
		    new rpID = GetPlayerRoadPointID(playerid);
			if(rpID != -1)
		    {
		        new line = ffindLine(rpID);
				fdeleteline("KYLRoadPoints.txt", line);
				if(IsValidDynamicPickup(RP[CZ[playerid]][slot][PickupID]))
				{
			    	DestroyDynamicPickup(RP[CZ[playerid]][slot][PickupID]);
		  			RP[CZ[playerid]][slot][PickupID] = -1;
				}
				if(IsValidDynamicMapIcon(RP[CZ[playerid]][slot][MapIconID]))
				{
				    DestroyDynamicMapIcon(RP[CZ[playerid]][slot][MapIconID]);
				    RP[CZ[playerid]][slot][MapIconID] = -1;
				}
			    RP[CZ[playerid]][slot][X] = 0.0;
			    RP[CZ[playerid]][slot][Y] = 0.0;
			    RP[CZ[playerid]][slot][Z] = 0.0;
			    RP[CZ[playerid]][slot][A] = 0.0;
			    RP[CZ[playerid]][slot][D] = 0.0;
			    RP[CZ[playerid]][slot][ID] = -1;
			    ATRP--;
			}
		}
	}
	else
	{
		if(IsCreating == true && IsPauzed == false)  // Check if AutoCreaton-mode is enabled
		{
	    	if(RPCreator == playerid)  // Check if playerid is the creator
	    	{
				new Float:vX, Float:vY, Float:vZ;  // Create 3 new floats to store the current position
				new vid = GetPlayerVehicleID(playerid);
				GetVehiclePos(vid, vX, vY, vZ);  //Retrieve the current vehicle position
				if(GetDistance(lastX, lastY, lastZ, vX, vY, vZ) >= AutoCreateDistance)  //Check if the distance between the current position and the previous created RoadPoint is equal or larger than the distance set by the creator
				{
				    if(Double == false)
				    {
					    new Float:vA; //Create new float to store the current vehicle angle
					    GetVehicleZAngle(vid, vA);  //Retrieve the vehicles driving direction
						new slot = GetFreeSlot(CZ[playerid]);  //Get the first empty slot in the array of that zone
					    if(slot == -1)   //...if there is no empty slot available in the current zone
					    {
							IsCreating = false;   // Disable the Creation-mode
							RPCreator = -1;            // Reset the playerid assigned to the RPCreator value
					    	SendClientMessage(playerid, 0xFF0000AA, "[Error] - The max amount of RoadPoints per zone has been reached!"); // Send error-message to the creator
					        SendClientMessage(playerid, 0xFF0000AA, "Increae the MAX_ROADPOINTS_PER_ZONE define at the top of the filterscript and reload"); // Send error-message to the creator
					        SendClientMessage(playerid, 0xFF0000AA, "Auto Creation of RoadPoints has been disabled"); // Send error-message to the creator
							return 1;
						}
						else // If an empty slot in the current zone is found...
						{

							RP[CZ[playerid]][slot][X] = vX;  //Store the current X postion as the new RoadPoint X position
							RP[CZ[playerid]][slot][Y] = vY;  //Store the current Y postion as the new RoadPoint Y position
							RP[CZ[playerid]][slot][Z] = vZ;  //Store the current Z postion as the new RoadPoint Z position
							RP[CZ[playerid]][slot][A] = vA;  //Store the current angle as the new RoadPoint suppossed driving-direction.
							RP[CZ[playerid]][slot][D] = floatdiv(RoadWidth, 2.0);
							RP[CZ[playerid]][slot][ID] = TRP; // Set the ID of the new RoadPoint as current amount of RoadPoints
							RP[CZ[playerid]][slot][MapIconID] = CreateDynamicMapIcon(RP[CZ[playerid]][slot][X], RP[CZ[playerid]][slot][Y], RP[CZ[playerid]][slot][Z], 56, 0, -1, -1, playerid, 300.0, MAPICON_LOCAL);
							RP[CZ[playerid]][slot][PickupID] = CreateDynamicPickup(1318, 23, RP[CZ[playerid]][slot][X], RP[CZ[playerid]][slot][Y], RP[CZ[playerid]][slot][Z], -1, -1, playerid, 200.0);
							TRP++;  //Increase the total amount of RoadPoints
							ATRP++;
							SaveRoadPoint(vX, vY, vZ, vA, RoadWidth);  // This function will write the newly created RoadPoint to the KYLRoadPoints.txt file.
							UpdateTextDraws(playerid);
							lastX = vX;  // Store the current X-position in the lastX variable, to be used on the next update;
							lastY = vY;  // Store the current Y-position in the lastY variable, to be used on the next update;
							lastZ = vZ;  // Store the current Z-position in the lastZ variable, to be used on the next update;
						}
					}
					else if(Double == true)
					{
					    new Float:vA;
					    new Float:rX, Float:rY, Float:rZ, Float:rA;
					    new Float:lX, Float:lY, Float:lZ, Float:lA;
						GetVehicleZAngle(vid, vA);
						
						PositionFromVehicleOffset(vid, floatadd(floatdiv(RoadWidth, 2), floatdiv(Space, 2.0)), 0.0, 0.0, rX, rY, rZ);
						PositionFromVehicleOffset(vid, -floatadd(floatdiv(RoadWidth, 2), floatdiv(Space, 2.0)), 0.0, 0.0, lX, lY, lZ);
					
						rA = vA;
						lA = floatadd(vA, 180);
						if(lA >= 360.0)
						{
							lA = floatsub(lA, 360.0);
						}
						new zone = GetZone(lX, lY); // Retrieve the zone which the player is currently in.
						new slot = GetFreeSlot(zone);  //Get the first empty slot in the array of that zone
					    if(slot == -1)   //...if there is no empty slot available in the current zone
					    {
							IsCreating = false;   // Disable the Creation-mode
							RPCreator = -1;            // Reset the playerid assigned to the RPCreator value
					    	SendClientMessage(playerid, 0xFF0000AA, "[Error] - The max amount of RoadPoints per zone has been reached!"); // Send error-message to the creator
					        SendClientMessage(playerid, 0xFF0000AA, "Increae the MAX_ROADPOINTS_PER_ZONE define at the top of the filterscript and reload"); // Send error-message to the creator
					        SendClientMessage(playerid, 0xFF0000AA, "Auto Creation of RoadPoints has been disabled"); // Send error-message to the creator
							return 1;
						}
						else // If an empty slot in the current zone is found...
						{
							RP[zone][slot][X] = lX;  //Store the current X postion as the new RoadPoint X position
							RP[zone][slot][Y] = lY;  //Store the current Y postion as the new RoadPoint Y position
							RP[zone][slot][Z] = vZ;  //Store the current Z postion as the new RoadPoint Z position
							RP[zone][slot][A] = lA;  //Store the current angle as the new RoadPoint suppossed driving-direction.
							RP[zone][slot][D] = floatdiv(RoadWidth, 2.0);
							RP[zone][slot][ID] = TRP; // Set the ID of the new RoadPoint as current amount of RoadPoints

						 	RP[zone][slot][MapIconID] = CreateDynamicMapIcon(lX, lY, lZ, 56, 0, -1, -1, playerid, 300.0, MAPICON_LOCAL);
							RP[zone][slot][PickupID] = CreateDynamicPickup(1318, 23, lX, lY, lZ, -1, -1, playerid, 200.0);
	                        SaveRoadPoint(lX, lY, lZ, lA, RoadWidth);  // This function will write the newly created RoadPoint to the KYLRoadPoints.txt file.

							TRP++;
							ATRP++;
							UpdateTextDraws(playerid);
						}
	                    zone = GetZone(rX, rY); // Retrieve the zone which the player is currently in.
						slot = GetFreeSlot(zone);  //Get the first empty slot in the array of that zone
					    if(slot == -1)   //...if there is no empty slot available in the current zone
					    {
							IsCreating = false;   // Disable the Creation-mode
							RPCreator = -1;            // Reset the playerid assigned to the RPCreator value
					    	SendClientMessage(playerid, 0xFF0000AA, "[Error] - The max amount of RoadPoints per zone has been reached!"); // Send error-message to the creator
					        SendClientMessage(playerid, 0xFF0000AA, "Increae the MAX_ROADPOINTS_PER_ZONE define at the top of the filterscript and reload"); // Send error-message to the creator
					        SendClientMessage(playerid, 0xFF0000AA, "Auto Creation of RoadPoints has been disabled"); // Send error-message to the creator
							return 1;
						}
						else
						{
							RP[zone][slot][X] = rX;  //Store the current X postion as the new RoadPoint X position
							RP[zone][slot][Y] = rY;  //Store the current Y postion as the new RoadPoint Y position
							RP[zone][slot][Z] = rZ;  //Store the current Z postion as the new RoadPoint Z position
							RP[zone][slot][A] = rA;  //Store the current angle as the new RoadPoint suppossed driving-direction.
							RP[zone][slot][D] = floatdiv(RoadWidth, 2.0);
							RP[zone][slot][ID] = TRP; // Set the ID of the new RoadPoint as current amount of RoadPoints
						 	RP[zone][slot][MapIconID] = CreateDynamicMapIcon(rX, rY, rZ, 56, 0, -1, -1, playerid, 300.0, MAPICON_LOCAL);
							RP[zone][slot][PickupID] = CreateDynamicPickup(1318, 23, rX, rY, rZ, -1, -1, playerid, 200.0);
	                        SaveRoadPoint(rX, rY, rZ, rA, RoadWidth);

							TRP++;  //Increase the total amount of RoadPoints
							ATRP++;
							UpdateTextDraws(playerid);

							lastX = vX;  // Store the current X-position in the lastX variable, to be used on the next update;
							lastY = vY;  // Store the current Y-position in the lastY variable, to be used on the next update;
							lastZ = vZ;  // Store the current Z-position in the lastZ variable, to be used on the next update;
						}



					}
				}
			}
		}
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

public OnPlayerClickTextDraw(playerid, Text:clickedid)
{
	if(clickedid == Textdraw8)  // Delete RoadPoint
	{
	    CancelSelectTextDraw(playerid);
		new slot = GetPlayerRoadPointSlot(playerid);
	    if(slot == -1) return SendClientMessage(playerid, 0xFF0000AA, "[Error] - You are not near a RoadPoint)");
	    new rpID = GetPlayerRoadPointID(playerid);
		if(rpID != -1)
	    {
	        new line = ffindLine(rpID);
			fdeleteline("KYLRoadPoints.txt", line);
			if(IsValidDynamicPickup(RP[CZ[playerid]][slot][PickupID]))
			{
		    	DestroyDynamicPickup(RP[CZ[playerid]][slot][PickupID]);
	  			RP[CZ[playerid]][slot][PickupID] = -1;
			}
			if(IsValidDynamicMapIcon(RP[CZ[playerid]][slot][MapIconID]))
			{
			    DestroyDynamicMapIcon(RP[CZ[playerid]][slot][MapIconID]);
			    RP[CZ[playerid]][slot][MapIconID] = -1;
			}
		    RP[CZ[playerid]][slot][X] = 0.0;
		    RP[CZ[playerid]][slot][Y] = 0.0;
		    RP[CZ[playerid]][slot][Z] = 0.0;
		    RP[CZ[playerid]][slot][A] = 0.0;
		    RP[CZ[playerid]][slot][D] = 0.0;
		    RP[CZ[playerid]][slot][ID] = -1;
		    SendClientMessage(playerid, 0x00FF0000AA, "RoadPoint deleted");
		    ATRP--;
		}
		else
		{
			SendClientMessage(playerid, 0xFF0000AA, "[Error] - Invalid RoadPoint");
		}
	}
	
	if(clickedid == Textdraw2)  //Pauze/Enable
	{
	    CancelSelectTextDraw(playerid);
	    if(IsPauzed == false)
	    {
	        IsPauzed = true;
 		}
		else
		{
			IsPauzed = false;
		}
	}
	
	if(clickedid == Textdraw4)  // Smaller RoadType
	{
		if(RoadWidth > 1.0)
		{
			RoadWidth = floatsub(RoadWidth, 0.25);
			if(RoadWidth < 1.0)
			{
			    RoadWidth = 1.0;
			}
		}
		if(Double == true)
		{
		    UpdateObjects(playerid, 1, 1);
		}
		else
		{
 			UpdateObjects(playerid, 0, 0);
		}
	}

	if(clickedid == Textdraw6)  // LargerRoadType
	{
	    RoadWidth = floatadd(RoadWidth, 0.25);
   		if(Double == true)
		{
		    UpdateObjects(playerid, 1, 1);
		}
		else
		{
			UpdateObjects(playerid, 0, 0);
		}

	}
	if(clickedid == Textdraw9)   // Lower Distance
	{
		AutoCreateDistance = floatsub(AutoCreateDistance, 1.0);
	}
	if(clickedid == Textdraw13)  // Increase Distance
	{
	    AutoCreateDistance = floatadd(AutoCreateDistance, 1.0);
	}

	if(clickedid == Textdraw15)  // Enable/Disable Double
	{
 	    if(Double == true)
	    {
	        Double = false;
			UpdateObjects(playerid, 1, 0);
		}
		else
		{
			Double = true;
			UpdateObjects(playerid, 0, 1);
		}
 	}
 	if(clickedid == Textdraw17)   // Decrease space
	{
		Space = floatsub(Space, 0.20);
		if(Space < 0.2)
		{
		    Space = 0.2;
		}
		UpdateObjects(playerid, 1, 1);
	}

	if(clickedid == Textdraw18)  // Increase space
	{
		Space = floatadd(Space, 0.20);
		
		UpdateObjects(playerid, 1, 1);
	}

	if(clickedid == Textdraw23)  // Preset 1;
	{
	    RoadWidth = Preset[0][prewidth];
		AutoCreateDistance = Preset[0][predistance];
		Space = Preset[0][prespace];
	    if(Double == false)
	    {
	    	if(Preset[0][predouble] == 1) { Double = true; UpdateObjects(playerid, 0, 1); }
      	    else { Double = false; UpdateObjects(playerid, 0, 0); }
		}
  		else
		{
		    if(Preset[0][predouble] == 1) {	Double = true; UpdateObjects(playerid, 1, 1); }
      	    else { Double = false; UpdateObjects(playerid, 1, 0); }
		}
	}
	if(clickedid == Textdraw24)  // Preset 2;
	{
	    RoadWidth = Preset[1][prewidth];
		AutoCreateDistance = Preset[1][predistance];
		Space = Preset[1][prespace];
	    if(Double == false)
	    {
	    	if(Preset[1][predouble] == 1) { Double = true; UpdateObjects(playerid, 0, 1); }
      	    else { Double = false; UpdateObjects(playerid, 0, 0); }
		}
  		else
		{
		    if(Preset[1][predouble] == 1) {	Double = true; UpdateObjects(playerid, 1, 1); }
      	    else { Double = false; UpdateObjects(playerid, 1, 0); }
		}
	}
	if(clickedid == Textdraw25)  // Preset 3;
	{
	    RoadWidth = Preset[2][prewidth];
		AutoCreateDistance = Preset[2][predistance];
		Space = Preset[2][prespace];
	    if(Double == false)
	    {
	    	if(Preset[2][predouble] == 1) { Double = true; UpdateObjects(playerid, 0, 1); }
      	    else { Double = false; UpdateObjects(playerid, 0, 0); }
		}
  		else
		{
		    if(Preset[2][predouble] == 1) {	Double = true; UpdateObjects(playerid, 1, 1); }
      	    else { Double = false; UpdateObjects(playerid, 1, 0); }
		}
	}
	if(clickedid == Textdraw26)  // Preset 4;
	{
	    RoadWidth = Preset[3][prewidth];
		AutoCreateDistance = Preset[3][predistance];
		Space = Preset[3][prespace];
	    if(Double == false)
	    {
	    	if(Preset[3][predouble] == 1) { Double = true; UpdateObjects(playerid, 0, 1); }
      	    else { Double = false; UpdateObjects(playerid, 0, 0); }
		}
  		else
		{
		    if(Preset[3][predouble] == 1) {
			Double = true; UpdateObjects(playerid, 1, 1); }
      	    else { Double = false; UpdateObjects(playerid, 1, 0); }
		}
	}
	if(clickedid == Textdraw27)  // Preset 1;
	{
	    RoadWidth = Preset[4][prewidth];
		AutoCreateDistance = Preset[4][predistance];
		Space = Preset[4][prespace];
	    if(Double == false)
	    {
	    	if(Preset[4][predouble] == 1) { Double = true; UpdateObjects(playerid, 0, 1); }
      	    else { Double = false; UpdateObjects(playerid, 0, 0); }
		}
  		else
		{
		    if(Preset[4][predouble] == 1) {	Double = true; UpdateObjects(playerid, 1, 1); }
      	    else { Double = false; UpdateObjects(playerid, 1, 0); }
		}
	}
	UpdateTextDraws(playerid);
	return 1;
}


COMMAND:getzone(playerid, params[])
{
	new Float:x, Float:y, Float:z, zone;
	GetPlayerPos(playerid, x, y, z);
	zone = GetZone(x, y);
	new str[32];
	format(str, 32, "Zone: %d", zone);
	SendClientMessage(playerid, -1, str);
	return 1;
}

COMMAND:createrp(playerid, params[])
{
    if(!IsPlayerAdmin(playerid)) return 0;
    if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER) return SendClientMessage(playerid, 0xFF0000AA, "[Error] - You need to be driving a vehicle first!");
    if(IsCreating == true)
    {
        IsCreating = false;
		RPCreator = -1;
		Double = false;
		IsPauzed = true;
		IsDeleting = false;
		
		HideTextDraws(playerid);
		
		UpdateObjects(playerid, 1, -1);
		
		SendClientMessage(playerid, 0x00FF00AA, "Auto RP-Creation Mode Disabled");
		for(new zone; zone<145; zone++)
		{
		    for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)
		    {
		        if(IsValidDynamicPickup(RP[zone][slot][PickupID]))
				{
			    	DestroyDynamicPickup(RP[zone][slot][PickupID]);
  					RP[zone][slot][PickupID] = -1;
				}
				if(IsValidDynamicMapIcon(RP[zone][slot][MapIconID]))
				{
				    DestroyDynamicMapIcon(RP[zone][slot][MapIconID]);
				    RP[zone][slot][MapIconID] = -1;
				}
			}
		}
		return 1;
	}
	RPCreator = playerid;
	IsCreating = true;
	IsPauzed = true;
	for(new zone; zone<145; zone++)
	{
	    for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)
	    {
	        if((RP[zone][slot][X] != 0.0) && (RP[zone][slot][Y] != 0.0) && (RP[zone][slot][Z] != 0.0))
	        {
		    	RP[zone][slot][PickupID] = CreateDynamicPickup(1318, 23, RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z], -1, -1, playerid, 200.0);
		    	RP[zone][slot][MapIconID] = CreateDynamicMapIcon(RP[zone][slot][X], RP[zone][slot][Y], RP[zone][slot][Z], 56, 0, -1, -1, playerid, 300.0, MAPICON_LOCAL);
			}
		}
	}
    if(Double == true) UpdateObjects(playerid, -1, 1);
    else UpdateObjects(playerid, -1, 0);
    
    new Float:x, Float:y, Float:z;
	GetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
	SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
    UpdateTextDraws(playerid);
	ShowTextDraws(playerid);
	
	return 1;
}

COMMAND:deleterp(playerid, params[])
{
	if(RPCreator != playerid) return 0;
    if(!IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, 0xFF0000AA, "[Error] - You need to be driving a vehicle first!");
	IsPauzed = true;
	IsDeleting = true;
	SendClientMessage(playerid, -1, "You are now deleting every RoadPoint you drive through. To cancel, press the handbrake!");
	UpdateTextDraws(playerid);
	return 1;
}

COMMAND:presets(playerid, params[])
{
	if(RPCreator != playerid) return 0;
	if(ShowPresets == false)
	{
		ShowPresets = true;
		TextDrawShowForPlayer(playerid, Textdraw21);
		TextDrawShowForPlayer(playerid, Textdraw22);
		TextDrawShowForPlayer(playerid, Textdraw23);
		TextDrawShowForPlayer(playerid, Textdraw24);
		TextDrawShowForPlayer(playerid, Textdraw25);
		TextDrawShowForPlayer(playerid, Textdraw26);
		TextDrawShowForPlayer(playerid, Textdraw27);
	}
	else
	{
		ShowPresets = false;
		TextDrawHideForPlayer(playerid, Textdraw21);
		TextDrawHideForPlayer(playerid, Textdraw22);
		TextDrawHideForPlayer(playerid, Textdraw23);
		TextDrawHideForPlayer(playerid, Textdraw24);
		TextDrawHideForPlayer(playerid, Textdraw25);
		TextDrawHideForPlayer(playerid, Textdraw26);
		TextDrawHideForPlayer(playerid, Textdraw27);
	}
	UpdateTextDraws(playerid);
	return 1;
}

COMMAND:savepreset(playerid, params[])
{
    if(RPCreator != playerid) return 0;
    new slot;
	if(sscanf(params, "d", slot)) return SendClientMessage(playerid, 0xFF0000FF, "Error: Use /savepreset [1-5]");
	if((slot < 1) || (slot > 5)) return SendClientMessage(playerid, 0xFF0000FF, "Error: Use /savepreset [1-5]");
	slot--;
	if(Double == true)
	{
		Preset[slot][predouble] = 1;
		format(Preset[slot][predoublestr], 12, "Double");
	}
	else
	{
		Preset[slot][predouble] = 0;
		format(Preset[slot][predoublestr], 12, "Single");
	}
	Preset[slot][prewidth] = RoadWidth;
	Preset[slot][predistance] = AutoCreateDistance;
	Preset[slot][prespace] = Space;
	SendClientMessage(playerid, -1, "Preset saved");
	UpdateTextDraws(playerid);
	SavePresets();
	return 1;
}

COMMAND:straight(playerid, params[])
{
    if(RPCreator != playerid) return 0;
    new Float:vA, vid = GetPlayerVehicleID(playerid);
    GetVehicleZAngle(vid, vA);
    if((vA >= 315) || (vA < 45)) SetVehicleZAngle(vid, 0.0);
    if((vA >= 45) && (vA < 135)) SetVehicleZAngle(vid, 90.0);
	if((vA >= 135) && (vA < 225)) SetVehicleZAngle(vid, 180.0);
	if((vA >= 225) && (vA < 315)) SetVehicleZAngle(vid, 270.0);
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
			RP[zone][slot][PickupID] = -1; //Reset pickup IDif(IsValidDynamicMapIcon(RP[zone][slot][MapIconID]))
		    RP[zone][slot][MapIconID] = -1;
		}
 	}
	return 1;
}

stock SaveRoadPoint(Float:rX, Float:rY, Float:rZ, Float:rA, Float:width) // This function writes the newly created RoadPoint to the KYLRoadPoints.txt file
{
	new File:file=fopen("KYLRoadPoints.txt", io_append);  // Open the file
	new str[64];  // Create new strin
	format(str, sizeof(str), "%.3f %.3f %.3f %.2f %.2f\r\n", rX, rY, rZ, rA, floatdiv(width, 2.0)); // format the string to contain the X, Y, Z coordinates, angle and distance
	fwrite(file, str);  // Write the string to the file
 	fclose(file);  // Close the file
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
				ATRP++;
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

ffindLine(rpID)  // This function returns the line in KYLRoadPoints.txt which contains all info of the RoadPoints with the given ID.
{
    new line = -1;  // Create varibale to store the linenumber and set it to -1 to start with
	new rpzone = -1, rpslot = -1;  // Create variables to store the zone and slot the RoadPoint is stored in
	for(new zone; zone<145; zone++)  // Loop through all 37 zones
	{
	    for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)  // In each zone loop through all slots
	    {
	        if(RP[zone][slot][ID] == rpID)  // If the ID stored in the current zone and slot matches the given ID...
	        {
	            rpzone = zone; // Store the zone-number in the rpzone variable
	            rpslot = slot; // Store the slot-number in the rpslot variable
				break; // Stop the loop.
			}
		}
	}
	
	if((rpzone != -1) && (rpslot != -1))  // Check if a matching zone and slot has been found
	{
	    new str[64]; // Create new string
		new count = -1; // Create variable that counts the number of lines that has been compared
	    new File:file=fopen("KYLRoadPoints.txt", io_read);  // Open the file
	    new Float:rX, Float:rY, Float:rZ;  // Create variables to temporarily store the coordintes from each line in the file
	 	while(fread(file, str))  // Loop through all lines in the file
 		{
 			count++;  // Increae count by 1
 			sscanf(str, "fff", rX, rY, rZ);  // Retrieve the first 3 values from the line and store them in the temporarily variables
  			{
				if((floatround(RP[rpzone][rpslot][X]) == floatround(rX)) && (floatround(RP[rpzone][rpslot][Y]) == floatround(rY)) && (floatround(RP[rpzone][rpslot][Z]) == floatround(rZ)))
				{
				    line = (count+1);  // If the coordinates match set the line-variable to the current count
				    break;
  				}
			}
		}
		fclose(file); // Close the file
	}
	return line; // Return the line-number
}



forward Float:GetDistance(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2);
stock Float:GetDistance(Float:x1, Float:y1, Float:z1, Float:x2, Float:y2, Float:z2)  // This function calculates and returns the distance between 2 points.
{
    return floatsqroot( ( ( x1 - x2 ) * ( x1 - x2 ) ) + ( ( y1 - y2 ) * ( y1 - y2 ) ) + ( ( z1 - z2 ) * ( z1 - z2 ) ) );
}

forward CheckRoadPoints();
public CheckRoadPoints()   // This is the main function that checks the players position and sees if he's driving on the wrong side of the road:
{
	new slot, rtrn; // Create some variables to temporarily store values.
	for(new i; i<MAX_PLAYERS; i++) // Loop through all players
	{
	    if(i == RPCreator)  // If the playerid is currently creating new RoadPoints, update the textdraws:
	    {
	        UpdateTextDraws(i);
		}
		
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
			if(rtrn == 1) CallRemoteFunction("OnPlayerGhostDriving", "ddffff", i, CZ[i], RP[CZ[i]][slot][X], RP[CZ[i]][slot][Y], RP[CZ[i]][slot][Z], RP[CZ[i]][slot][A]);
			else if(rtrn == -1)  // If no close RoadPoint is found... scan the next surrounding zone and repeat if for all 4 surrounding zones (unless a point is found.
			{
			    new zone = CZ[i]+1;
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
	

GetPlayerRoadPointSlot(playerid) // This function checks if the player is in range of any RoadPoint and returns its slot ID  (returns -1 if not in range of any point).
{
	if(!IsPlayerInAnyVehicle(playerid)) return -1;
	new rp = -1;
	for(new slot; slot<MAX_ROADPOINTS_PER_ZONE; slot++)
	{
		if(IsPlayerInRangeOfPoint(playerid, 2, RP[CZ[playerid]][slot][X], RP[CZ[playerid]][slot][Y], RP[CZ[playerid]][slot][Z]))
		{
			rp = slot;
		}
	}
	return rp;
}

stock GetPlayerRoadPointID(playerid)  // This function checks if the player is in range of any RoadPoint and returns its unique ID. (Returns -1 if the player is not in range of any RoadPoint)
{
	new slot = GetPlayerRoadPointSlot(playerid);
	if(slot == -1)
	{
	    return -1;
	}
	else
	{
		return RP[CZ[playerid]][slot][ID];
	}
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

fdeleteline(filename[], line)  // This functions deletes the given line from the file (Function created by: Sacky)
{

  new count, string[256], File:file, File:temp;
  file= fopen(filename, io_read);
  temp = fopen("tmpfile.tmp", io_write);

  while (fread(file, string))
    if (++count != line)
      fwrite(temp, string);

  fclose(file);
  fclose(temp);

  file= fopen(filename, io_write);
  temp = fopen("tmpfile.tmp", io_read);

  while (fread(temp, string))
    fwrite(file, string);

  fclose(file);
  fclose(temp);
  fremove("tmpfile.tmp");
}

stock ShowTextDraws(playerid)
{
    TextDrawShowForPlayer(playerid, Textdraw0);
	TextDrawShowForPlayer(playerid, Textdraw1);
	TextDrawShowForPlayer(playerid, Textdraw2);
	TextDrawShowForPlayer(playerid, Textdraw3);
	TextDrawShowForPlayer(playerid, Textdraw4);
	TextDrawShowForPlayer(playerid, Textdraw5);
	TextDrawShowForPlayer(playerid, Textdraw6);
	TextDrawShowForPlayer(playerid, Textdraw7);
	TextDrawShowForPlayer(playerid, Textdraw8);
	TextDrawShowForPlayer(playerid, Textdraw9);
	TextDrawShowForPlayer(playerid, Textdraw10);
	TextDrawShowForPlayer(playerid, Textdraw11);
	TextDrawShowForPlayer(playerid, Textdraw12);
	TextDrawShowForPlayer(playerid, Textdraw13);
	TextDrawShowForPlayer(playerid, Textdraw14);
	TextDrawShowForPlayer(playerid, Textdraw15);
	if(Double == true)
	{
		TextDrawShowForPlayer(playerid, Textdraw16);
		TextDrawShowForPlayer(playerid, Textdraw17);
		TextDrawShowForPlayer(playerid, Textdraw18);
		TextDrawShowForPlayer(playerid, Textdraw19);
		TextDrawShowForPlayer(playerid, Textdraw20);
	}
	return 1;
}

stock HideTextDraws(playerid)
{
    TextDrawHideForPlayer(playerid, Textdraw0);
	TextDrawHideForPlayer(playerid, Textdraw1);
	TextDrawHideForPlayer(playerid, Textdraw2);
	TextDrawHideForPlayer(playerid, Textdraw3);
	TextDrawHideForPlayer(playerid, Textdraw4);
	TextDrawHideForPlayer(playerid, Textdraw5);
	TextDrawHideForPlayer(playerid, Textdraw6);
	TextDrawHideForPlayer(playerid, Textdraw7);
	TextDrawHideForPlayer(playerid, Textdraw8);
	TextDrawHideForPlayer(playerid, Textdraw9);
	TextDrawHideForPlayer(playerid, Textdraw10);
	TextDrawHideForPlayer(playerid, Textdraw11);
	TextDrawHideForPlayer(playerid, Textdraw12);
	TextDrawHideForPlayer(playerid, Textdraw13);
	TextDrawHideForPlayer(playerid, Textdraw14);
	TextDrawHideForPlayer(playerid, Textdraw15);
	TextDrawHideForPlayer(playerid, Textdraw16);
	TextDrawHideForPlayer(playerid, Textdraw17);
	TextDrawHideForPlayer(playerid, Textdraw18);
	TextDrawHideForPlayer(playerid, Textdraw19);
	TextDrawHideForPlayer(playerid, Textdraw20);
	TextDrawHideForPlayer(playerid, Textdraw21);
	TextDrawHideForPlayer(playerid, Textdraw22);
	TextDrawHideForPlayer(playerid, Textdraw23);
	TextDrawHideForPlayer(playerid, Textdraw24);
	TextDrawHideForPlayer(playerid, Textdraw25);
	TextDrawHideForPlayer(playerid, Textdraw26);
	TextDrawHideForPlayer(playerid, Textdraw27);
	return 1;
}
	


stock UpdateTextDraws(playerid)
{
	TextDrawHideForPlayer(playerid, Textdraw2);
	TextDrawHideForPlayer(playerid, Textdraw5);
	TextDrawHideForPlayer(playerid, Textdraw10);
	TextDrawHideForPlayer(playerid, Textdraw12);
	TextDrawHideForPlayer(playerid, Textdraw15);
	if(Double == true)
	{
		TextDrawHideForPlayer(playerid, Textdraw16);
		TextDrawHideForPlayer(playerid, Textdraw17);
		TextDrawHideForPlayer(playerid, Textdraw18);
		TextDrawHideForPlayer(playerid, Textdraw19);
		TextDrawHideForPlayer(playerid, Textdraw20);
		TextDrawColor(Textdraw15, TD_BRIGHTGREEN);
		format(td15str, sizeof(td15str), "ON");
		format(td19str, sizeof(td19str), "%.2f", Space);
		TextDrawSetString(Textdraw19, td19str);
		TextDrawShowForPlayer(playerid, Textdraw16);
		TextDrawShowForPlayer(playerid, Textdraw17);
		TextDrawShowForPlayer(playerid, Textdraw18);
		TextDrawShowForPlayer(playerid, Textdraw19);
		TextDrawShowForPlayer(playerid, Textdraw20);
	}
	else
	{
	    TextDrawHideForPlayer(playerid, Textdraw15);
	    TextDrawHideForPlayer(playerid, Textdraw16);
	    TextDrawHideForPlayer(playerid, Textdraw17);
	    TextDrawHideForPlayer(playerid, Textdraw18);
	    TextDrawHideForPlayer(playerid, Textdraw19);
		TextDrawHideForPlayer(playerid, Textdraw20);
		TextDrawColor(Textdraw15, TD_BRIGHTRED);
		format(td15str, sizeof(td15str), "OFF");
	}
	if(IsDeleting == true)
	{
	    format(td2str, sizeof(td2str), "DELETING!");
		TextDrawColor(Textdraw2, TD_BRIGHTRED);
	}
	else
	{
		if(IsPauzed == false)
		{
			format(td2str, sizeof(td2str), "Enabled");
			TextDrawColor(Textdraw2, TD_BRIGHTGREEN);
		}
		else
		{
			format(td2str, sizeof(td2str), "Pauzed");
			TextDrawColor(Textdraw2, TD_BRIGHTRED);
		}
	}
	format(td5str, sizeof(td5str), "%.2f", RoadWidth);
	format(td10str, sizeof(td10str), "%.2f", AutoCreateDistance);
	format(td12str, sizeof(td12str), "%d", ATRP);
    TextDrawSetString(Textdraw2, td2str);
    TextDrawSetString(Textdraw5, td5str);
	TextDrawSetString(Textdraw10, td10str);
	TextDrawSetString(Textdraw12, td12str);
	TextDrawSetString(Textdraw15, td15str);
    TextDrawShowForPlayer(playerid, Textdraw2);
    TextDrawShowForPlayer(playerid, Textdraw5);
    TextDrawShowForPlayer(playerid, Textdraw10);
    TextDrawShowForPlayer(playerid, Textdraw12);
    TextDrawShowForPlayer(playerid, Textdraw15);
    if(ShowPresets == true)
    {
		format(pre1str, sizeof(pre1str), "#1: %s - %.2f - %.2f - %.2f", Preset[0][predoublestr], Preset[0][prewidth], Preset[0][predistance], Preset[0][prespace]);
		format(pre2str, sizeof(pre2str), "#2: %s - %.2f - %.2f - %.2f", Preset[1][predoublestr], Preset[1][prewidth], Preset[1][predistance], Preset[1][prespace]);
		format(pre3str, sizeof(pre3str), "#3: %s - %.2f - %.2f - %.2f", Preset[2][predoublestr], Preset[2][prewidth], Preset[2][predistance], Preset[2][prespace]);
		format(pre4str, sizeof(pre4str), "#4: %s - %.2f - %.2f - %.2f", Preset[3][predoublestr], Preset[3][prewidth], Preset[3][predistance], Preset[3][prespace]);
		format(pre5str, sizeof(pre5str), "#5: %s - %.2f - %.2f - %.2f", Preset[4][predoublestr], Preset[4][prewidth], Preset[4][predistance], Preset[4][prespace]);
		TextDrawHideForPlayer(playerid, Textdraw23);
		TextDrawHideForPlayer(playerid, Textdraw24);
		TextDrawHideForPlayer(playerid, Textdraw25);
		TextDrawHideForPlayer(playerid, Textdraw26);
		TextDrawHideForPlayer(playerid, Textdraw27);
		TextDrawSetString(Textdraw23, pre1str);
		TextDrawSetString(Textdraw24, pre2str);
		TextDrawSetString(Textdraw25, pre3str);
		TextDrawSetString(Textdraw26, pre4str);
		TextDrawSetString(Textdraw27, pre5str);
		TextDrawShowForPlayer(playerid, Textdraw23);
		TextDrawShowForPlayer(playerid, Textdraw24);
		TextDrawShowForPlayer(playerid, Textdraw25);
		TextDrawShowForPlayer(playerid, Textdraw26);
		TextDrawShowForPlayer(playerid, Textdraw27);
	}
    return 1;
}
    
CreateTextDraws()
{
    Textdraw0 = TextDrawCreate(322.000000, 451.000000, "~n~");    // Background Box
	TextDrawAlignment(Textdraw0, 2);
	TextDrawBackgroundColor(Textdraw0, 255);
	TextDrawFont(Textdraw0, 1);
	TextDrawLetterSize(Textdraw0, -0.559997, -2.599998);
	TextDrawColor(Textdraw0, -1);
	TextDrawSetOutline(Textdraw0, 0);
	TextDrawSetProportional(Textdraw0, 1);
	TextDrawSetShadow(Textdraw0, 1);
	TextDrawUseBox(Textdraw0, 1);
	TextDrawBoxColor(Textdraw0, 150);
	TextDrawTextSize(Textdraw0, 35.000000, 642.000000);
	TextDrawSetSelectable(Textdraw0, 0);

	Textdraw1 = TextDrawCreate(13.000000, 432.000000, "~y~RoadPoint Creator:");
	TextDrawBackgroundColor(Textdraw1, 255);
	TextDrawFont(Textdraw1, 1);
	TextDrawLetterSize(Textdraw1, 0.200000, 1.200000);
	TextDrawColor(Textdraw1, -1);
	TextDrawSetOutline(Textdraw1, 1);
	TextDrawSetProportional(Textdraw1, 1);
	TextDrawSetSelectable(Textdraw1, 0);

	Textdraw2 = TextDrawCreate(83.000000, 432.000000, td2str);         //Current Status  (Pauzed/Enabled)
	TextDrawBackgroundColor(Textdraw2, 255);
	TextDrawFont(Textdraw2, 1);
	TextDrawLetterSize(Textdraw2, 0.310000, 1.200000);
	TextDrawColor(Textdraw2, -1);
	TextDrawSetOutline(Textdraw2, 1);
	TextDrawSetProportional(Textdraw2, 1);
	TextDrawUseBox(Textdraw2, 1);
	TextDrawBoxColor(Textdraw2, 0);
	TextDrawTextSize(Textdraw2, 125.000000, 30.000000);
	TextDrawSetSelectable(Textdraw2, 1);

	Textdraw3 = TextDrawCreate(146.000000, 432.000000, "~y~Roadwidth:");
	TextDrawBackgroundColor(Textdraw3, 255);
	TextDrawFont(Textdraw3, 1);
	TextDrawLetterSize(Textdraw3, 0.240000, 1.200000);
	TextDrawColor(Textdraw3, -1);
	TextDrawSetOutline(Textdraw3, 1);
	TextDrawSetProportional(Textdraw3, 1);
	TextDrawSetSelectable(Textdraw3, 0);

	Textdraw4 = TextDrawCreate(192.000000, 427.000000, "<");      //Decrease Width Button
	TextDrawBackgroundColor(Textdraw4, 255);
	TextDrawFont(Textdraw4, 1);
	TextDrawLetterSize(Textdraw4, 0.500000, 2.400000);
	TextDrawColor(Textdraw4, TD_BLUE);
	TextDrawSetOutline(Textdraw4, 1);
	TextDrawSetProportional(Textdraw4, 1);
	TextDrawUseBox(Textdraw4, 1);
	TextDrawBoxColor(Textdraw4, 0);
	TextDrawTextSize(Textdraw4, 206.000000, 30.000000);
	TextDrawSetSelectable(Textdraw4, 1);

	Textdraw5 = TextDrawCreate(235.000000, 432.000000, td5str);    //Current RoadType
	TextDrawAlignment(Textdraw5, 2);
	TextDrawBackgroundColor(Textdraw5, 255);
	TextDrawFont(Textdraw5, 1);
	TextDrawLetterSize(Textdraw5, 0.250000, 1.200000);
	TextDrawColor(Textdraw5, TD_BRIGHTGREEN);
	TextDrawSetOutline(Textdraw5, 1);
	TextDrawSetProportional(Textdraw5, 1);
	TextDrawSetSelectable(Textdraw5, 0);

	Textdraw6 = TextDrawCreate(267.000000, 427.000000, ">");    //Increase Width Button
	TextDrawBackgroundColor(Textdraw6, 255);
	TextDrawFont(Textdraw6, 1);
	TextDrawLetterSize(Textdraw6, 0.500000, 2.400000);
	TextDrawColor(Textdraw6, TD_BLUE);
	TextDrawSetOutline(Textdraw6, 1);
	TextDrawSetProportional(Textdraw6, 1);
	TextDrawUseBox(Textdraw6, 1);
	TextDrawBoxColor(Textdraw6, 0);
	TextDrawTextSize(Textdraw6, 279.000000, 30.000000);
	TextDrawSetSelectable(Textdraw6, 1);

	Textdraw7 = TextDrawCreate(297.000000, 432.000000, "~y~Distance:");
	TextDrawBackgroundColor(Textdraw7, 255);
	TextDrawFont(Textdraw7, 1);
	TextDrawLetterSize(Textdraw7, 0.270000, 1.200000);
	TextDrawColor(Textdraw7, -1);
	TextDrawSetOutline(Textdraw7, 1);
	TextDrawSetProportional(Textdraw7, 1);
	TextDrawSetSelectable(Textdraw7, 0);

	Textdraw8 = TextDrawCreate(494.000000, 432.000000, "Delete");    // Delete Button
	TextDrawBackgroundColor(Textdraw8, 255);
	TextDrawFont(Textdraw8, 1);
	TextDrawLetterSize(Textdraw8, 0.289999, 1.200000);
	TextDrawColor(Textdraw8, -16777016);
	TextDrawSetOutline(Textdraw8, 1);
	TextDrawSetProportional(Textdraw8, 1);
	TextDrawUseBox(Textdraw8, 1);
	TextDrawBoxColor(Textdraw8, 0);
	TextDrawTextSize(Textdraw8, 526.000000, 30.000000);
	TextDrawSetSelectable(Textdraw8, 1);

	Textdraw9 = TextDrawCreate(341.000000, 427.000000, "<");    //Decreate Distance Button
	TextDrawBackgroundColor(Textdraw9, 255);
	TextDrawFont(Textdraw9, 1);
	TextDrawLetterSize(Textdraw9, 0.500000, 2.400000);
	TextDrawColor(Textdraw9, TD_BLUE);
	TextDrawSetOutline(Textdraw9, 1);
	TextDrawSetProportional(Textdraw9, 1);
	TextDrawUseBox(Textdraw9, 1);
	TextDrawBoxColor(Textdraw9, 0);
	TextDrawTextSize(Textdraw9, 354.000000, 30.000000);
	TextDrawSetSelectable(Textdraw9, 1);

	Textdraw10 = TextDrawCreate(368.000000, 432.000000, td10str);    // Current Distance
	TextDrawAlignment(Textdraw10, 2);
	TextDrawBackgroundColor(Textdraw10, 255);
	TextDrawFont(Textdraw10, 1);
	TextDrawLetterSize(Textdraw10, 0.310000, 1.200000);
	TextDrawColor(Textdraw10, TD_BRIGHTGREEN);
	TextDrawSetOutline(Textdraw10, 1);
	TextDrawSetProportional(Textdraw10, 1);
	TextDrawSetSelectable(Textdraw10, 0);

	Textdraw11 = TextDrawCreate(552.00000, 432.000000, "~y~RoadPoints:");
	TextDrawBackgroundColor(Textdraw11, 255);
	TextDrawFont(Textdraw11, 1);
	TextDrawLetterSize(Textdraw11, 0.240000, 1.200000);
	TextDrawColor(Textdraw11, -1);
	TextDrawSetOutline(Textdraw11, 1);
	TextDrawSetProportional(Textdraw11, 1);
	TextDrawSetSelectable(Textdraw11, 0);

	Textdraw12 = TextDrawCreate(602.000000, 432.000000, td12str);    // Roadpoints Counter
	TextDrawBackgroundColor(Textdraw12, 255);
	TextDrawFont(Textdraw12, 1);
	TextDrawLetterSize(Textdraw12, 0.239999, 1.200000);
	TextDrawColor(Textdraw12, TD_BRIGHTGREEN);
	TextDrawSetOutline(Textdraw12, 1);
	TextDrawSetProportional(Textdraw12, 1);
	TextDrawSetSelectable(Textdraw12, 0);

	Textdraw13 = TextDrawCreate(383.000000, 427.000000, ">");    //Increase Distance Button
	TextDrawBackgroundColor(Textdraw13, 255);
	TextDrawFont(Textdraw13, 1);
	TextDrawLetterSize(Textdraw13, 0.500000, 2.400000);
	TextDrawColor(Textdraw13, TD_BLUE);
	TextDrawSetOutline(Textdraw13, 1);
	TextDrawSetProportional(Textdraw13, 1);
	TextDrawUseBox(Textdraw13, 1);
	TextDrawBoxColor(Textdraw13, 0);
	TextDrawTextSize(Textdraw13, 395.000000, 30.000000);
	TextDrawSetSelectable(Textdraw13, 1);

	Textdraw14 = TextDrawCreate(412.000000, 432.000000, "~y~Double:");
	TextDrawBackgroundColor(Textdraw14, 255);
	TextDrawFont(Textdraw14, 1);
	TextDrawLetterSize(Textdraw14, 0.270000, 1.200000);
	TextDrawColor(Textdraw14, -1);
	TextDrawSetOutline(Textdraw14, 1);
	TextDrawSetProportional(Textdraw14, 1);
	TextDrawSetSelectable(Textdraw14, 0);

	Textdraw15 = TextDrawCreate(450.000000, 432.000000, td15str);   // Double ON/OFF button
	TextDrawBackgroundColor(Textdraw15, 255);
	TextDrawFont(Textdraw15, 1);
	TextDrawLetterSize(Textdraw15, 0.270000, 1.200000);
	TextDrawColor(Textdraw15, TD_BRIGHTRED);
	TextDrawSetOutline(Textdraw15, 1);
	TextDrawSetProportional(Textdraw15, 1);
	TextDrawUseBox(Textdraw15, 1);
	TextDrawBoxColor(Textdraw15, 0);
	TextDrawTextSize(Textdraw15, 469.000000, 30.000000);
	TextDrawSetSelectable(Textdraw15, 1);

   	Textdraw20 = TextDrawCreate(855.000000, 428.000000, "~n~");
	TextDrawAlignment(Textdraw20, 2);
	TextDrawBackgroundColor(Textdraw20, 255);
	TextDrawFont(Textdraw20, 1);
	TextDrawLetterSize(Textdraw20, -0.559997, -2.599998);
	TextDrawColor(Textdraw20, -1);
	TextDrawSetOutline(Textdraw20, 0);
	TextDrawSetProportional(Textdraw20, 1);
	TextDrawSetShadow(Textdraw20, 1);
	TextDrawUseBox(Textdraw20, 1);
	TextDrawBoxColor(Textdraw20, 150);
	TextDrawTextSize(Textdraw20, 35.000000, 642.000000);
	TextDrawSetSelectable(Textdraw20, 0);

	Textdraw16 = TextDrawCreate(537.000000, 408.000000, "~y~Space:");
	TextDrawBackgroundColor(Textdraw16, 255);
	TextDrawFont(Textdraw16, 1);
	TextDrawLetterSize(Textdraw16, 0.289999, 1.500000);
	TextDrawColor(Textdraw16, -1);
	TextDrawSetOutline(Textdraw16, 1);
	TextDrawSetProportional(Textdraw16, 1);
	TextDrawSetSelectable(Textdraw16, 0);

	Textdraw17 = TextDrawCreate(570.000000, 405.000000, "<");
	TextDrawBackgroundColor(Textdraw17, 255);
	TextDrawFont(Textdraw17, 1);
	TextDrawLetterSize(Textdraw17, 0.500000, 2.400000);
	TextDrawColor(Textdraw17, TD_BLUE);
	TextDrawSetOutline(Textdraw17, 1);
	TextDrawSetProportional(Textdraw17, 1);
	TextDrawUseBox(Textdraw17, 1);
	TextDrawBoxColor(Textdraw17, 0);
	TextDrawTextSize(Textdraw17, 586.000000, 33.000000);
	TextDrawSetSelectable(Textdraw17, 1);

	Textdraw18 = TextDrawCreate(612.000000, 405.000000, ">");
	TextDrawBackgroundColor(Textdraw18, 255);
	TextDrawFont(Textdraw18, 1);
	TextDrawLetterSize(Textdraw18, 0.500000, 2.400000);
	TextDrawColor(Textdraw18, TD_BLUE);
	TextDrawSetOutline(Textdraw18, 1);
	TextDrawSetProportional(Textdraw18, 1);
	TextDrawUseBox(Textdraw18, 1);
	TextDrawBoxColor(Textdraw18, 0);
	TextDrawTextSize(Textdraw18, 626.000000, 35.000000);
	TextDrawSetSelectable(Textdraw18, 1);

	Textdraw19 = TextDrawCreate(597.000000, 408.000000, td19str);
	TextDrawAlignment(Textdraw19, 2);
	TextDrawBackgroundColor(Textdraw19, 255);
	TextDrawFont(Textdraw19, 1);
	TextDrawLetterSize(Textdraw19, 0.329997, 1.700000);
	TextDrawColor(Textdraw19, TD_BRIGHTGREEN);
	TextDrawSetOutline(Textdraw19, 1);
	TextDrawSetProportional(Textdraw19, 1);
	TextDrawSetSelectable(Textdraw19, 0);

    Textdraw21 = TextDrawCreate(111.000000, 218.000000, "~n~");
	TextDrawAlignment(Textdraw21, 2);
	TextDrawBackgroundColor(Textdraw21, 255);
	TextDrawFont(Textdraw21, 1);
	TextDrawLetterSize(Textdraw21, 0.069999, 11.999987);
	TextDrawColor(Textdraw21, -1);
	TextDrawSetOutline(Textdraw21, 0);
	TextDrawSetProportional(Textdraw21, 1);
	TextDrawSetShadow(Textdraw21, 1);
	TextDrawUseBox(Textdraw21, 1);
	TextDrawBoxColor(Textdraw21, 125);
	TextDrawTextSize(Textdraw21, -10.000000, -180.000000);
	TextDrawSetSelectable(Textdraw21, 0);

	Textdraw22 = TextDrawCreate(30.000000, 220.000000, "Presets:~n~#          width - dist. - space");
	TextDrawBackgroundColor(Textdraw22, 255);
	TextDrawFont(Textdraw22, 1);
	TextDrawLetterSize(Textdraw22, 0.290000, 1.000000);
	TextDrawColor(Textdraw22, -1);
	TextDrawSetOutline(Textdraw22, 1);
	TextDrawSetProportional(Textdraw22, 1);
	TextDrawSetSelectable(Textdraw22, 0);

	Textdraw23 = TextDrawCreate(30.000000, 245.000000, pre1str);
	TextDrawBackgroundColor(Textdraw23, 255);
	TextDrawFont(Textdraw23, 1);
	TextDrawLetterSize(Textdraw23, 0.270000, 1.100000);
	TextDrawColor(Textdraw23, -1);
	TextDrawSetOutline(Textdraw23, 1);
	TextDrawSetProportional(Textdraw23, 1);
	TextDrawUseBox(Textdraw23, 1);
	TextDrawBoxColor(Textdraw23, 150);
	TextDrawTextSize(Textdraw23, 197.000000, 15.000000);
	TextDrawSetSelectable(Textdraw23, 1);

	Textdraw24 = TextDrawCreate(30.000000, 261.000000, pre2str);
	TextDrawBackgroundColor(Textdraw24, 255);
	TextDrawFont(Textdraw24, 1);
	TextDrawLetterSize(Textdraw24, 0.270000, 1.100000);
	TextDrawColor(Textdraw24, -1);
	TextDrawSetOutline(Textdraw24, 1);
	TextDrawSetProportional(Textdraw24, 1);
	TextDrawUseBox(Textdraw24, 1);
	TextDrawBoxColor(Textdraw24, 150);
	TextDrawTextSize(Textdraw24, 197.000000, 15.000000);
	TextDrawSetSelectable(Textdraw24, 1);

	Textdraw25 = TextDrawCreate(30.000000, 277.000000, pre3str);
	TextDrawBackgroundColor(Textdraw25, 255);
	TextDrawFont(Textdraw25, 1);
	TextDrawLetterSize(Textdraw25, 0.270000, 1.100000);
	TextDrawColor(Textdraw25, -1);
	TextDrawSetOutline(Textdraw25, 1);
	TextDrawSetProportional(Textdraw25, 1);
	TextDrawUseBox(Textdraw25, 1);
	TextDrawBoxColor(Textdraw25, 150);
	TextDrawTextSize(Textdraw25, 197.000000, 15.000000);
	TextDrawSetSelectable(Textdraw25, 1);

	Textdraw26 = TextDrawCreate(30.000000, 293.000000, pre4str);
	TextDrawBackgroundColor(Textdraw26, 255);
	TextDrawFont(Textdraw26, 1);
	TextDrawLetterSize(Textdraw26, 0.270000, 1.100000);
	TextDrawColor(Textdraw26, -1);
	TextDrawSetOutline(Textdraw26, 1);
	TextDrawSetProportional(Textdraw26, 1);
	TextDrawUseBox(Textdraw26, 1);
	TextDrawBoxColor(Textdraw26, 150);
	TextDrawTextSize(Textdraw26, 197.000000, 15.000000);
	TextDrawSetSelectable(Textdraw26, 1);

	Textdraw27 = TextDrawCreate(30.000000, 309.000000, pre5str);
	TextDrawBackgroundColor(Textdraw27, 255);
	TextDrawFont(Textdraw27, 1);
	TextDrawLetterSize(Textdraw27, 0.270000, 1.100000);
	TextDrawColor(Textdraw27, -1);
	TextDrawSetOutline(Textdraw27, 1);
	TextDrawSetProportional(Textdraw27, 1);
	TextDrawUseBox(Textdraw27, 1);
	TextDrawBoxColor(Textdraw27, 150);
	TextDrawTextSize(Textdraw27, 197.000000, 15.000000);
	TextDrawSetSelectable(Textdraw27, 1);
	return 1;
}


stock SavePresets()
{
	new File:file;
    if (!fexist("KYLSettings.txt"))
    {
    	file = fopen("KYLSettings.txt",io_write);
    	fclose(file);
	}
	file=fopen("KYLSettings.txt", io_write);
	new str[64];
	for(new slot; slot<5; slot++)
	{
		format(str, sizeof(str), "%d %s %.2f %.2f %.2f\r\n", Preset[slot][predouble], Preset[slot][predoublestr], Preset[slot][prewidth], Preset[slot][predistance], Preset[slot][prespace]);
		fwrite(file, str);
	}
 	fclose(file);
 	return 1;
}

stock LoadPresets()
{
	new File:file;
    if (!fexist("KYLSettings.txt"))
    {
    	file = fopen("KYLSettings.txt",io_write);
    	fclose(file);
	}
	file=fopen("KYLSettings.txt", io_read);
	new str[64], slot;  // Create new variables to store the string, zone and slot
 	while(fread(file, str))  // Loop through each line in the file
 	{
 	    
	 	sscanf(str, "ds[12]fff", Preset[slot][predouble], Preset[slot][predoublestr], Preset[slot][prewidth], Preset[slot][predistance], Preset[slot][prespace]);  // Retrieve all values from the line and store them in the temporarily variables
		slot++;
	}
	fclose(file);
	return 1;
}


//This function creates, deletes and/or updates the position of the objects/markers attached to your vehicle during the Creation-process, based on the old state and new state.
UpdateObjects(playerid, oldstate, newstate)
{

	//States:
	//  -1  = Creation-mode Disabled
	//  0   = Creating Roadpoints in 1 direction
	//  1   = Creating Roadpoints in both directions
	
    new Float:x, Float:y, Float:z;
    switch (oldstate)
    {
        case -1:
		{
		    switch (newstate)
		    {
		        case 0:
		        {
		            Object1 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    AttachDynamicObjectToVehicle(Object1, GetPlayerVehicleID(playerid), (floatdiv(RoadWidth, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
				    Object2 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    AttachDynamicObjectToVehicle(Object2, GetPlayerVehicleID(playerid), -(floatdiv(RoadWidth, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
				    GetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
					SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
		        }
		    }
		}
		case 0:
 		{
		    switch (newstate)
		    {
		        case -1:
		        {
                    if(IsValidDynamicObject(Object1)) DestroyDynamicObject(Object1);
				    if(IsValidDynamicObject(Object2)) DestroyDynamicObject(Object2);
				    if(IsValidDynamicObject(Object3)) DestroyDynamicObject(Object3);
				    if(IsValidDynamicObject(Object4)) DestroyDynamicObject(Object4);
		        }
		        case 0:
				{
				    if(!IsValidDynamicObject(Object1)) Object1 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    if(!IsValidDynamicObject(Object2)) Object2 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
			        AttachDynamicObjectToVehicle(Object1, GetPlayerVehicleID(playerid), (floatdiv(RoadWidth, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
			  		AttachDynamicObjectToVehicle(Object2, GetPlayerVehicleID(playerid), -(floatdiv(RoadWidth, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
			  		GetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
					SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
				}
		        case 1:
		        {
                    if(!IsValidDynamicObject(Object1)) Object1 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    if(!IsValidDynamicObject(Object2)) Object2 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    Object3 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
			        Object4 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
					AttachDynamicObjectToVehicle(Object1, GetPlayerVehicleID(playerid), floatadd(RoadWidth, floatdiv(Space, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
					AttachDynamicObjectToVehicle(Object2, GetPlayerVehicleID(playerid), floatdiv(Space, 2.0), 0.0, -0.5, 0.0, 0.0, 0.0);
					AttachDynamicObjectToVehicle(Object3, GetPlayerVehicleID(playerid), -floatdiv(Space, 2.0), 0.0, -0.5, 0.0, 0.0, 0.0);
					AttachDynamicObjectToVehicle(Object4, GetPlayerVehicleID(playerid), -floatadd(RoadWidth, floatdiv(Space, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
					GetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
					SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
		        }
		    }
		}
		case 1:
		{
		    switch (newstate)
		    {
		        case -1:
		        {
		            if(IsValidDynamicObject(Object1)) DestroyDynamicObject(Object1);
				    if(IsValidDynamicObject(Object2)) DestroyDynamicObject(Object2);
				    if(IsValidDynamicObject(Object3)) DestroyDynamicObject(Object3);
				    if(IsValidDynamicObject(Object4)) DestroyDynamicObject(Object4);
		        }
		        case 0:
		        {
		            if(IsValidDynamicObject(Object1)) DestroyDynamicObject(Object1);
				    if(IsValidDynamicObject(Object2)) DestroyDynamicObject(Object2);
				    if(IsValidDynamicObject(Object3)) DestroyDynamicObject(Object3);
				    if(IsValidDynamicObject(Object4)) DestroyDynamicObject(Object4);
		            Object1 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    AttachDynamicObjectToVehicle(Object1, GetPlayerVehicleID(playerid), (floatdiv(RoadWidth, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
				    Object2 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    AttachDynamicObjectToVehicle(Object2, GetPlayerVehicleID(playerid), -(floatdiv(RoadWidth, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
				    GetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
					SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);

		        }
		        case 1:
		        {
                    if(!IsValidDynamicObject(Object1)) Object1 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    if(!IsValidDynamicObject(Object2)) Object2 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
				    if(!IsValidDynamicObject(Object3)) Object3 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
			        if(!IsValidDynamicObject(Object4)) Object4 = CreateDynamicObject(19133, 0.0, 0.0, 0.0, 0.0, 0,0, -1, -1, -1);
					AttachDynamicObjectToVehicle(Object1, GetPlayerVehicleID(playerid), floatadd(RoadWidth, floatdiv(Space, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
					AttachDynamicObjectToVehicle(Object2, GetPlayerVehicleID(playerid), floatdiv(Space, 2.0), 0.0, -0.5, 0.0, 0.0, 0.0);
					AttachDynamicObjectToVehicle(Object3, GetPlayerVehicleID(playerid), -floatdiv(Space, 2.0), 0.0, -0.5, 0.0, 0.0, 0.0);
					AttachDynamicObjectToVehicle(Object4, GetPlayerVehicleID(playerid), -floatadd(RoadWidth, floatdiv(Space, 2.0)), 0.0, -0.5, 0.0, 0.0, 0.0);
					GetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
					SetVehiclePos(GetPlayerVehicleID(playerid), x, y, z);
				}
		    }
		}
	}
	return 1;
}
