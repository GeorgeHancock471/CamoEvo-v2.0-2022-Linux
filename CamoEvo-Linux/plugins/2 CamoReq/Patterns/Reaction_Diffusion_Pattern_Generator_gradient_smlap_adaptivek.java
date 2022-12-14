/*__________________________________________________________________

	Title: Gray-Scott Reaction Diffusion Model
	''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	Author: Jolyon Troscianko
	Date: 8/1/2018
............................................................................................................

This code generates Reaction Diffusion patterns.

The algorithm joins opposite edges, meaning the patterns can be tiled, and the growth
is effectively on a torus-type surface.

The starting condition is: all "A" concentrations to 1, and all "B" concentrations to 0,
except for a randomly located vertical line 1 px thick, where "B" concentrations are 1.

The concentrations of A and B are limited between 0 and 1.

Random noise is added to A and B, which helps stabilise pattern growth with low values,
and at high values breaks up the patterns

The patterns grow from their random start column to their surroundings. Once the
patterns reach the opposite end of the image the growth continues for a length
of time dependant on the width of the image. Small images require additional extra
growth time for the patterns to start to stabilise. An exponential decay is used to 
calculate the number of additional steps y = 5000*0.996^w where w is image width px.

Useful descriptions:
http://www.algosome.com/articles/reaction-diffusion-gray-scott.html
http://www.mrob.com/pub/comp/xmorphia/

Useful example code:
https://codepen.io/eskimoblood/pen/sFKkc


____________________________________________________________________
*/

import ij.*;
import ij.plugin.PlugIn;
import ij.process.*;
import ij.gui.*;


public class Reaction_Diffusion_Pattern_Generator_gradient_smlap_adaptivek implements PlugIn {
public void run(String arg) {

IJ.showStatus("Reaction Diffusion");

int w = 2000;
int h = 2000;
int nSteps = 4000; // maximum number of steps
double randomFeed = 0.01;

double fy =  0.0;
double fmin =  0.005;
double fmax = 0.09;

double kx = 0.0;
double kmin = 0.03;
double kmax = 0.14;

double Da = 0.2;
double Db = Da/2;

int recSlice = 100;

/*

Keeping k around 0.77 works well.
f = 0.020 = fail
f = 0.0215 = spots (homogeneous, fails with small images)
f = 0.022 = spots (wobbly)
f = 0.023 = stripes (less connected)
f = 0.024 = stripes (quite connected)
f = 0.025 = inverse spots (only form when image is large enough, around 200)
f = 0.026 = chaotic markings
f = 0.027 = mottle (due to random values)
above with noise around 0.01, values below this don't seem to make a difference
highest noise should  be around 0.2, 0.05 is intermediate/high, 0.01 is intermediate, 0.001 is low

*/


//-------f-k modelling
//Formula: y = a+bx+cx^2+dx^3+ex^4


double akmin =  0.018931;
double bkmin = 3.08807;
double ckmin = -40.27581;
double dkmin = 371.87151;
double ekmin = -1466.18323;

double akmax = 0.037916;
double bkmax = 2.57107;
double ckmax = -30.29821;
double dkmax = 213.43023;
double ekmax = -454.62195;


/* // pretty good bounds (though kmin should have about 0.003 subtracted:
double akmin =  0.017424;
double bkmin = 3.12147;
double ckmin = -33.87557;
double dkmin = 233.31663;
double ekmin = -730.92651;



double akmax = 0.041987;
double bkmax = 2.35771;
double ckmax = -23.94580;
double dkmax = 147.36734;
double ekmax = -243.50137;
*/



GenericDialog gd = new GenericDialog("Reaction Diffusion Pattern Generation");
		gd.addMessage("Pattern Generation Values");
		gd.addNumericField("fmin Feed rate", fmin, 5);
		gd.addNumericField("fmax Feed rate", fmax, 5);
		//gd.addNumericField("kmin Kill rate", kmin, 5);
		//gd.addNumericField("kmax Kill rate", kmax, 5);
		gd.addNumericField("Da Diffusion rate", Da, 5);
		gd.addNumericField("Db Diffusion rate", Db, 5);
		gd.addNumericField("noise", randomFeed, 5);
		gd.addNumericField("Max steps", nSteps, 0);
		gd.addMessage("Image Dimensions");
		gd.addNumericField("w Width", w, 0);
		gd.addNumericField("h Height", h, 0);
		gd.addNumericField("Output slice frequency", recSlice, 0);
gd.showDialog();
	if (gd.wasCanceled())
		return;

	
fmin = gd.getNextNumber();
fmax = gd.getNextNumber();
//kmin = gd.getNextNumber();
//kmax = gd.getNextNumber();

Da = gd.getNextNumber();
Db = gd.getNextNumber();
randomFeed = gd.getNextNumber();
nSteps = (int) Math.round( gd.getNextNumber());
w = (int) Math.round( gd.getNextNumber());
h = (int) Math.round( gd.getNextNumber());
recSlice = (int) Math.round( gd.getNextNumber());


//---------------------Set up environment------------------

int dimension = w*h;

double[] outA = new double[dimension];
double[] outB = new double[dimension];
double[] A = new double[dimension];
double[] B = new double[dimension];

// initialise image
for(int i=0; i<dimension; i++){
	A[i] = 1;
	B[i] = 0;
}

/*

// draw a vertical line in a random column of the image as a starting point
//int midRow = (int) (Math.round(Math.random()*(w-1)));
int midRow = Math.round(w/2);

for(int y=0; y<h; y++)
	B[(y*w)+midRow] = 1;

if(midRow >= Math.round(w/2)) // prepare midRow for finding the opposite side of the image (i.e last pixels to be filled)
	midRow = midRow - Math.round(w/2);
else midRow = midRow + Math.round(w/2);


//for(int i=0; i<dimension; i++)
//	B[i] = Math.round(Math.random()*Math.random());

*/


int randLoc = 0;

// random start points
//for(int i=0; i<(w+h)/2; i++){
for(int i=0; i<(w+h); i++){

	randLoc = (int) Math.round(Math.random()*(dimension-(2*h)-(2*w))+1+w);

	B[randLoc] = 1.0;

	B[randLoc - w] = 1.0;
	B[randLoc - 1] = 1.0;
	B[randLoc + w] = 1.0;
	B[randLoc + 1] = 1.0;

	B[randLoc - w -1] = 0.2;
	B[randLoc - w +1] = 0.2;
	B[randLoc + w -1] = 0.2;
	B[randLoc + w +1] = 0.2;


}



double Aval = 0.0;
double Bval = 0.0;

double convCount = 0.0; // used to work with image edges
double cA = 0.0; // convolution sum A
double cB = 0.0; // convolution sum A

double maxB = 0.0;
double minB = 10E10;
double xBSum = 0.0;
int rowsFilled = 0;
int finalFlag = 0;

int pxid = 0;
double d2 = 0.0;
double randVal = 0.0;

int recSliceCounter = 0;

ImageStack outStack = new ImageStack(w, h);

for(int j=0; j<nSteps; j++){

recSliceCounter ++;

for (int y=1; y<h-1; y++){

fy = (double) (fmin + (fmax-fmin)*((y*1.0)/(h*1.0)));

//kmin = akmin + bkmin*fy + ckmin*fy*fy + dkmin*fy*fy*fy + ekmin*fy*fy*fy*fy - 0.003;
//kmax = akmax + bkmax*fy + ckmax*fy*fy + dkmax*fy*fy*fy + ekmax*fy*fy*fy*fy;

kmin = akmin + bkmin*fy + ckmin*fy*fy + dkmin*fy*fy*fy + ekmin*fy*fy*fy*fy;
kmax = akmax + bkmax*fy + ckmax*fy*fy + dkmax*fy*fy*fy + ekmax*fy*fy*fy*fy;


for (int x=1; x<w-1; x++){

	//Laplacian Convolution

	cA = 0.0;
	cB = 0.0;
	pxid = (y*w)+x;
	convCount = 0.0;

	//TOP-LEFT
		cA += 0.25*A[pxid - w - 1];
		cB += 0.25*B[pxid - w - 1];

	//TOP
		cA += A[pxid - w];
		cB += B[pxid - w];

	//TOP-RIGHT
		cA += 0.25*A[pxid - w + 1];
		cB += 0.25*B[pxid - w + 1];

	//LEFT
		cA += A[pxid - 1];
		cB += B[pxid - 1];

	//RIGHT
		cA += A[pxid + 1];
		cB += B[pxid + 1];

	//BOTTOM-LEFT
		cA += 0.25*A[pxid + w - 1];
		cB += 0.25*B[pxid + w - 1];

	//BOTTOM
		cA += A[pxid + w];
		cB += B[pxid + w];

	//BOTTOM-RIGHT
		cA += 0.25*A[pxid + w + 1];
		cB += 0.25*B[pxid + w + 1];


	// CENTRE


	Aval = A[pxid];
	Bval = B[pxid];
	
	d2 = Aval*Bval*Bval;

	kx = kmin + (kmax-kmin)*((x*1.0)/(w*1.0));

	outA[pxid] =    Aval + ((Da* ( cA - 5 * Aval) - d2) + fy * (1 - Aval)) ;
	outB[pxid] =    Bval + ((Db* ( cB - 5 * Bval) + d2) - kx *Bval) ;
	

}//x
}//y



for (int y=0; y<h; y++){
for (int x=0; x<w; x++){

	pxid = (y*w)+x;

	if(outA[pxid] > 1.0)
		A[pxid] = 1.0;
	else if(outA[pxid] < 0.0)
		A[pxid] = 0.0;	
	else A[pxid] = outA[pxid];

	if(outB[pxid] > 1.0)
		B[pxid] = 1.0;
	else if(outB[pxid] < 0.0)
		B[pxid] = 0.0;	
	else B[pxid] = outB[pxid];

	A[pxid] +=  randomFeed*(Math.random()-0.5);
	if(j>nSteps-1) // add noise to B channel except fot the last go
		B[pxid] += randomFeed*(Math.random()-0.5);

	xBSum += B[pxid];

}//x
}//y



IJ.showProgress((float) j/nSteps);


if(recSliceCounter >= recSlice){
	float[] Bfloat = new float[dimension];
	for(int i=0; i<dimension; i++)
		Bfloat[i] = (float) (B[i]);

	outStack.addSlice("Steps: " + (j+1), Bfloat);
	recSliceCounter = 0;
}


}//j steps

IJ.showProgress((float) 1);

new ImagePlus("fmin"+ fmin + " fmax"+ fmax + " rand" + randomFeed, outStack).show();


//-------create FK map--------------

float[] kmap = new float[dimension];
float[] fmap = new float[dimension];

ImageStack fkStack = new ImageStack(w, h);

for (int y=1; y<h-1; y++){

	fy = (double) (fmin + (fmax-fmin)*((y*1.0)/(h*1.0)));



	kmin = akmin + bkmin*fy + ckmin*fy*fy + dkmin*fy*fy*fy + ekmin*fy*fy*fy*fy;
	kmax = akmax + bkmax*fy + ckmax*fy*fy + dkmax*fy*fy*fy + ekmax*fy*fy*fy*fy;
	

	for (int x=1; x<w-1; x++){

		kx = kmin + (kmax-kmin)*((x*1.0)/(w*1.0));

		kmap[x+w*y] = (float) kx;
		fmap[x+w*y] = (float) fy;

	}//x

}//y

fkStack.addSlice("Feedrate", fmap);
fkStack.addSlice("Killrate", kmap);

new ImagePlus("Feed Kill maps", fkStack).show();


} // void
} //class
