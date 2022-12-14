/*
____________________________________________________________________________________________________

====================================================================================================
										Compare RNL Distance
====================================================================================================


 Written By: 	Jolyon Trosicanko and George Hancock

 Function: 	measures the average distance of RNL coordinates between RNL colour maps.
				lower values equate to lower distances with zero being the lowest possible.
				This tool can be useful for assessing how far away an object's colour is from 
				its background.

____________________________________________________________________________________________________
*/




// TestPoint
//---------------------------------------------------
// Allows you to obtain the index of a Value within an Array.

function TestPoint(Title) {
Dialog.createNonBlocking("TestPoint");
Dialog.createNonBlocking("Did " + Title + " work?");
Dialog.show();

}





settingsDefault=newArray(
"1",								//0 //Threshold
"Mean", 							//1 //Metric
"Yes"								//2 //Frequency					
)

defaultDIR = getDirectory("plugins")+"/micaToolbox/RNL Colour Maps/RNL_Settings/DistanceMeasure.txt"
settingsDefaultString = File.openAsString(defaultDIR);
tempSettings = split(settingsDefaultString,"\n");
if(tempSettings.length==settingsDefault.length) settingsDefault=tempSettings;



colOptions = newArray("Colour based on map location","Lock colours between slices", "Use colour palette");
roiManager("Show None");

yesNo = newArray("No","Yes");
metricArray=newArray("Mean","Max");

Dialog.create("Colour Map Distance  Settings");
	Dialog.addNumber("Threshold", parseFloat(settingsDefault[0]),4,6,"");
	Dialog.addChoice("Metric", metricArray,settingsDefault[1]);
	Dialog.addChoice("Frequency Weighting", yesNo,settingsDefault[2]);
Dialog.show();

PercentageV = Dialog.getNumber();
metricChoice = Dialog.getChoice();
yesNoChoice = Dialog.getChoice();


settingsDefault[0]=PercentageV; 
settingsDefault[1]=metricChoice;
settingsDefault[2]=yesNoChoice; 


File.delete(defaultDIR);

for(i=0;i<settingsDefault.length;i++){
File.append(settingsDefault[i], defaultDIR);
}






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



DoneArray=newArray(mapList.length);


//-----------------------------------Set Zero Threshold-------------------------


for(j=0; j<mapList.length; j++){
			selectImage(mapList[j]);
			run("Select None");
			
			// Stack Measure
			minMin=0;
			maxMax=0;
			for(S=0;S<nSlices;S++){
			setSlice(S+1);
			run("Select None");
			getStatistics(area,mean,min,max,dev);
			if(max>maxMax) maxMax=max;
			}
			minThresh = maxMax*(1-PercentageV);
			
			// Threshold
			setOption("BlackBackground", true);
			setThreshold(0,minThresh);
			sumSum=0;
					for(S=0;S<nSlices;S++){
					setSlice(S+1);
					run("Select None");
					getStatistics(area,mean,min,max);
					if(max<=minThresh){
					run("Set...","value=0 slice");
					}else{
					run("Create Selection");
					run("Set...","value=0 slice");
					run("Select None");
					getStatistics(area,mean);
					sumSum+=area*mean;
					}
					}//(S)
			run("Divide...","value=sumSum stack");
			}
			
		//setBatchMode("exit and display");
		//exit

//-----------------------------------Colour Overlap Measurement-------------------------
if(mapList.length > 1){

if(isOpen("Colour Distribution Overlap Measurements") == true){
	IJ.renameResults("Colour Distribution Overlap Measurements", "Results");
	
	Table.setLocationAndSize(300, 300,600,200);
	}
	

run("Clear Results");
row = nResults;

overlaps = newArray(mapList.length*mapList.length);


for(j=0; j<mapList.length; j++){

			
			selectImage(mapList[j]);
			run("Select None");
			presentArray1=newArray(nSlices);
			for(S=0;S<nSlices;S++){
			setSlice(S+1);
			getStatistics(area,mean,min,max);
			if(max>0) presentArray1[S]=1;
			}
			

	for(k=0; k<mapList.length; k++){

		if(k!=j){
		
			selectImage(mapList[k]);
			run("Select None");
			presentArray2=newArray(nSlices);
			for(S=0;S<nSlices;S++){
			setSlice(S+1);
			getStatistics(area,mean,min,max);
			if(max>0) presentArray2[S]=1;
			}
			
			
		
			run("Select None");
			

			distanceMeasureArray=newArray();
			xpointsF=newArray();
			ypointsF=newArray();
			zpointsF=newArray();
			fpointsF=newArray();
			FBpointsF=newArray();
			
			areaScale=0;
			
			for(S=0;S<nSlices;S++){
				if(presentArray1[S]==1){

				
				selectImage(mapList[j]);
				setSlice(S+1);
				run("Select None");
				setThreshold(0,0);
				run("Create Selection");
				
				run("Make Inverse");
				if(selectionType != -1) {  
				
				getSelectionCoordinates(xpoints1, ypoints1);
				getStatistics(areaScaleN);
				areaScale+=areaScaleN;
				
				
				freqArray=newArray(xpoints1.length);
				for(f=0;f<xpoints1.length;f++){
				freqArray[f] = getPixel(xpoints1[f],ypoints1[f]);
				}
				
				
				temp=xpoints1.length;
				for(f=0;f<temp;f++){
				v=temp-1-f;
				if(freqArray[v]==0){
				xpoints1=Array.deleteIndex(xpoints1,v);
				ypoints1=Array.deleteIndex(ypoints1,v);
				freqArray=Array.deleteIndex(freqArray,v);
				}
				}
				
				distanceMeasureArrayT=newArray(xpoints1.length);
				
				xpointsF=Array.concat(xpointsF,xpoints1);
				ypointsF=Array.concat(ypointsF,ypoints1);
				zpoints1=newArray(xpoints1.length);
				FBpoints1=newArray(xpoints1.length);
				
				fpointsF=Array.concat(fpointsF,freqArray);
				
				for(i=0;i<xpoints1.length;i++){
				zpoints1[i]=S;
				}
		
				zpointsF=Array.concat(zpointsF,zpoints1);
				
				selectImage(mapList[k]);
							
					for(checkPixel=0; checkPixel<xpoints1.length; checkPixel++){
					
					nearestMaxFreq=0;
						
					w=getWidth();
					h=getHeight();
					
					cap=w*h*nSlices;
					
					xO=xpoints1[checkPixel]-0.5;
					yO=ypoints1[checkPixel]-0.5;
					zO=S+1;
					
					setSlice(zO);
					
				
					found=0;
					radius=0.5;
					
					mean = getPixel(xO+0.5,yO+0.5);
					if(mean>0){ radius=0; found=1; nearestMaxFreq=mean;}
					

						while(found==0 && radius<cap){
						//setBatchMode("show");
						
						
						
						if(presentArray2[zO-1]==1){
						setSlice(zO);			
						makeOval(xO-radius,yO-radius,radius*2,radius*2);
						getStatistics(area,mean,min,max);			
						if(mean>0){
						found=1; nearestMaxFreq=max;
						}
						}

						if(nSlices>1){
						if(found==0){
						for(R=0;R<radius+1;R++){	
						nS=zO-R;
						if(nS>0){
							if(presentArray2[nS-1]==1){
							setSlice(nS);
							tempR=radius-R;
							if(tempR>0){
							makeOval(xO-tempR,yO-tempR,tempR*2,tempR*2);
							getStatistics(area,mean,min,max);			
								if(mean>0){
								found=1;  nearestMaxFreq=max;
								R=radius;
								}
							} else {
							mean = getPixel(xO,yO);
							getStatistics(area,mean,min,max);			
								if(mean>0){
								found=1;  nearestMaxFreq=max;
								R=radius;
								}
							}
							}
						}else{R=radius;}	
						}
						}

						if(found==0){
						for(R=0;R<radius+1;R++){	
						nS=zO+R;
						if(nS<=nSlices){
							if(presentArray2[nS-1]==1){
							setSlice(nS);
							tempR=radius-R;
							if(tempR>0){
							makeOval(xO-tempR,yO-tempR,tempR*2,tempR*2);
							getStatistics(area,mean,min,max);			
								if(mean>0){
								found=1;  nearestMaxFreq=max;
								R=radius;
								}
							} else {
							mean = getPixel(xO,yO);
							getStatistics(area,mean,min,max);			
								if(mean>0){
								found=1;  nearestMaxFreq=max;
								R=radius;
								}
							}
							}
						}else{R=radius;}		
						}
						}
						}//nslice>1



									
						if(found==0)radius=radius+0.5;
									
									
						}
						
					FBpoints1[checkPixel]=nearestMaxFreq;
						
					if(yesNoChoice=="Yes") radius=radius*freqArray[checkPixel];
					if(isNaN(radius)) radius=0;
					distanceMeasureArrayT[checkPixel] = radius;
				
					}//(Pixels)
					
					FBpointsF = Array.concat(FBpointsF,FBpoints1);
					
					distanceMeasureArray=Array.concat(distanceMeasureArray,distanceMeasureArrayT);
			
				}//Selection
				else { exit("error"); }
				}//Present
			}//(Slices)	
			
			
			if(distanceMeasureArray.length==0){
			Array.show("Present?",presentArray1,presentArray2);
			setBatchMode("exit and display");
			exit
			
			}
			

			
			Array.getStatistics(FBpointsF,min,max,mean);
			
			//Array.show(FBpointsF,fpointsF);
			//print("Freq FB",FBpointsF.length*mean);

			Array.getStatistics(fpointsF,min,max,meanF);
			//print("Freq",fpointsF.length*meanF);
	
			
			Array.getStatistics(distanceMeasureArray,min,MaxDistance,MeanDistance);
			
			if(metricChoice=="Mean") Measurement=MeanDistance;
			if(metricChoice=="Max") Measurement=MaxDistance;
			
			if(yesNoChoice=="Yes") Measurement=Measurement*distanceMeasureArray.length/(fpointsF.length*meanF);
			
			setResult(label[k], j, Measurement);	
			
			
			Array.getStatistics(presentArray1,min,max,MP1);
			Array.getStatistics(presentArray2,min,max,MP2);
			
			/*
			Array.show(FBpointsF,zpointsF,xpointsF,ypointsF,distanceMeasureArray);
			print("F Leng_"+label[j]+"_"+label[k]+"= ", FBpointsF.length);
			print("AreaScale",areaScale);
			print("Measure",Measurement);
			*/
			
			} else {
	
	setResult(label[k], j, 0);
	
	}//k!=j
	
	}//k
	
	
}//j




for(j=0; j<mapList.length; j++){
	setResult("Label", j, label[j]);

}//j

updateResults();
IJ.renameResults("Results","Colour Distribution Overlap Measurements");

}// if more than one map measure overlaps



