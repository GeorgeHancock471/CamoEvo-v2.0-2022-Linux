
setBatchMode(true);


//----------Find map images------------

alreadyOpen = 0;
imList = getList("image.titles");

mapList = newArray();

for(i=0; i<imList.length; i++){
	selectImage(imList[i]);
	mapInfo = getMetadata("Info");
	if(startsWith(mapInfo, "label=") == true)
		mapList = Array.concat(mapList, getImageID());
}

if(mapList.length > 0)
	alreadyOpen = 1;
else {
	path = getDirectory("Choose directory containing colour maps");
	list = getFileList(path);

	print("________________________________");
	print("Colour map files:");

	for(i=0; i<list.length; i++)
	if(endsWith(list[i], ".tif") == 1){
		print(list[i]);
		open(path + list[i]);
		mapInfo = getMetadata("Info");
		if(startsWith(mapInfo, "label=") == true)
			mapList = Array.concat(mapList, getImageID());
		else close();
	}
	print("________________________________");
}


if(mapList.length == 0)
	exit("There are no compatible maps; open all colour maps you wish to plot and compare and re-run");


//------arrays to hold info--------
label = newArray(mapList.length);
nPx = newArray(mapList.length);
res = newArray(mapList.length);
channelString = newArray(mapList.length);
label = newArray(mapList.length);
xMins = newArray(mapList.length);
yMins = newArray(mapList.length);
zMins = newArray(mapList.length);
xMaxs = newArray(mapList.length);
yMaxs = newArray(mapList.length);
zMaxs = newArray(mapList.length);
crop = newArray(mapList.length);
tetra = newArray(mapList.length); // flag for tetrachromatic images
tetra[0] = 0;
weber = newArray(mapList.length);

for(j=0; j<mapList.length; j++){

selectImage(mapList[j]);
mapInfo = getMetadata("Info");
mapInfo = split(mapInfo, ",");

for(i=0; i<mapInfo.length; i++){
	row = split(mapInfo[i], "=");
	
	if(row[0] == "label") label[j] = row[1];
	if(row[0] == "nPx") nPx[j] = parseInt(row[1]);
	if(row[0] == "res") res[j] = parseInt(row[1]);
	if(row[0] == "channels") channelString[j] = row[1];
	if(row[0] == "weber") weber[j] = row[1];
	if(row[0] == "x_limits"){
		xLims = split(row[1], ":");
		xMins[j] = parseInt(xLims[0]);
		xMaxs[j] = parseInt(xLims[1]);
	}
	if(row[0] == "y_limits"){
		yLims = split(row[1], ":");
		yMins[j] = parseInt(yLims[0]);
		yMaxs[j] = parseInt(yLims[1]);
	}
	if(row[0] == "z_limits"){
		zLims = split(row[1], ":");
		zMins[j] = parseInt(zLims[0]);
		zMaxs[j] = parseInt(zLims[1]);
		tetra[j] = 1;
	}	 
	//if(row[0] == "crop") crop[j] = row[1];
}

}//j


//-----------Work out final figure bounds---------------------

	cxMin = 10E10;
	cxMax = -10E10;
	cyMin = 10E10;
	cyMax = -10E10;
	for(j=0; j<mapList.length; j++){
		if(xMins[j] < cxMin) cxMin = xMins[j];
		if(yMins[j] < cyMin) cyMin = yMins[j];
		if(xMaxs[j] > cxMax) cxMax = xMaxs[j];
		if(yMaxs[j] > cyMax) cyMax = yMaxs[j];
	}


//--------------Crop z-axis-------------------
if(tetra[0] == 1){
	czMin = 10E10;
	czMax = -10E10;
	for(j=0; j<mapList.length; j++){
		if(zMins[j] < czMin) czMin = zMins[j];
		if(zMaxs[j] > czMax) czMax = zMaxs[j];
	}
}


//---------------Check all maps are compatible-------------

for(j=0; j<mapList.length; j++)
for(k=j+1; k<mapList.length; k++){
		if(res[j] != res[k]){
			print("Stopping - these maps are not compatible:");
			print(label[j] " map resolution = " + res[j]);
			print(label[k] " map resolution = " + res[k]);
			exit("Error - the resolutions of the colour maps do not match");
		}
		if(channelString[j] != channelString[k]){
			print("Stopping - these maps are not compatible:");
			print(label[j] " channel names = " + channelString[j]);
			print(label[k] " channel names = " + channelString[k]);
			exit("Error - the maps have different channel names");
		}
		if(weber[j] != weber[k]){
			print("Stopping - these maps are not compatible:");
			print(label[j] + " Weber fractions = " + weber[j]);
			print(label[k] + " Weber fractions = " + weber[k]);
			exit("Error - the maps have different weber fractions");
		}
		if(label[j] == label[k]){
			print("Warning, two colour maps share the same label.\nThey will be renamed:");
			print("Label 1: " + label[j] + "_1");
			print("Label 2: " + label[k] + "_2");
			label[j] = label[j]+"_1";
			label[k] = label[k]+"_2";
		}

}//j k


//--------------------------Expand maps to same size---------------------------
for(j=0; j<mapList.length; j++){

	selectImage(mapList[j]);

	mw = (xMaxs[j]-xMins[j])*res[0];
	mh = (yMaxs[j]-yMins[j])*res[0];

	selectImage(mapList[j]);
	run("Select All");
	run("Copy");
	ts = label[j] + "_Colour_Map";
	if(tetra[j] == 0){
		newImage(ts, "32-bit black", (cxMax-cxMin)*res[0], (cyMax-cyMin)*res[0], 1);
		makeRectangle((xMins[j]-cxMin)*res[0], (yMins[j]-cyMin)*res[0], mw, mh);
		run("Paste");
		nID = getImageID();
	} else {

		newImage(ts, "32-bit black", (cxMax-cxMin)*res[0], (cyMax-cyMin)*res[0], (czMax-czMin)*res[0]);
		nID = getImageID();
		//waitForUser("THIS BIT NEEDS SORTING");
		for(i=0; i<(zMaxs[j]-zMins[j])*res[0]; i++){
			selectImage(mapList[j]);
			//setSlice(i-(zMins[j]*res[0])+1);
			setSlice(i+1);
			run("Select All");
			run("Copy");
			selectImage(nID);
			setSlice((zMins[j]-czMin)*res[0]+i+1);
			//makeRectangle(xMins[j], yMins[j], mw, mh);
			makeRectangle((xMins[j]-cxMin)*res[0], (yMins[j]-cyMin)*res[0], mw, mh);
			run("Paste");
		}
		nID = getImageID();
	}

	selectImage(mapList[j]);
	close();

	selectImage(nID);
	mapList[j]=getImageID();

//---------Reset the image pixel count to reflect normalisation----------------

selectImage(mapList[j]);

	if(tetra[j] == 0){
		ts = "label=" + label[j] + ",nPx=1,res=" + res[j] +
			",channels=" + channelString[j] + ",x_limits=" + cxMin + ":" + cxMax +
			",y_limits=" + cyMin + ":" + cyMax;
	} else {
		ts = "label=" + label[j] + ",nPx=1,res=" + res[j] +
			",channels=" + channelString[j] + ",x_limits=" + cxMin + ":" + cxMax +
			",y_limits=" + cyMin + ":" + cyMax +
			",z_limits=" + czMin + ":" + czMax;
	}

setMetadata("Info", ts);


//-----------Normalise pixel counts---------------
selectImage(mapList[j]);
if(nPx[j] != 1){
	ts = "value=" + nPx[j];
	if(tetra[j] == 1)
		ts = ts + " stack";
	run("Divide...", ts);
}

if(alreadyOpen == 1)
	setBatchMode("show");
}//j


//-----------------------------------Colour Overlap Measurement-------------------------
if(mapList.length > 1){

if(isOpen("Colour Distribution Overlap Measurements") == true)
	IJ.renameResults("Colour Distribution Overlap Measurements", "Results");

run("Clear Results");
row = nResults;

overlaps = newArray(mapList.length*mapList.length);

for(j=0; j<mapList.length-1; j++){
	for(k=j+1; k<mapList.length; k++){
		if(tetra[j]==0){
			imageCalculator("Difference create 32-bit", mapList[j], mapList[k]);
			run("Select All");
			getStatistics(area, mean);
			close();
			overlaps[k+j*mapList.length] = (area*mean)/2;
			overlaps[j+k*mapList.length] = (area*mean)/2;
		} else {
			imageCalculator("Difference create 32-bit stack", mapList[j], mapList[k]);
			run("Select All");
			for(i=0; i<nSlices; i++){
				setSlice(i+1);
				getStatistics(area, mean);
				overlaps[k+j*mapList.length] += (area*mean)/2;
				overlaps[j+k*mapList.length] += (area*mean)/2;
			}
			close();
		}

		// due to 32-bit rounding error, when there is no overlap this can be slightly above 1
		if(overlaps[k+j*mapList.length] > 1) overlaps[k+j*mapList.length] = 1.0;
		if(overlaps[j+k*mapList.length] > 1) overlaps[j+k*mapList.length] = 1.0;
	}//k
}//j

for(j=0; j<mapList.length; j++){
	setResult("Label", row, label[j]);
	for(k=0; k<mapList.length; k++){
		if(k==j)
			overlaps[k+j*mapList.length] = 0;
		setResult(label[k], row, 1-overlaps[j+k*mapList.length]);
	}
	row++;
}//j

updateResults();
IJ.renameResults("Results","Colour Distribution Overlap Measurements");

}// if more than one map measure overlaps

