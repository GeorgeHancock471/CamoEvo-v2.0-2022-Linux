/*__________________________________________________________________

	Title: sRGB to XYZ
	''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
	Author: Jolyon Troscianko
	Date: 21/01/2020
............................................................................................................

Based on the reverse matrix here: https://www.image-engineering.de/library/technotes/958-how-to-convert-between-srgb-and-ciexyz

Note that these are the linear (R'G'B') values and need to go through gamma correction before being true sRGB values

____________________________________________________________________
*/


import ij.*;
import ij.plugin.filter.PlugInFilter;
import ij.process.*;

public class sRGB_to_CIEXYZ implements PlugInFilter {

ImageStack stack;
	public int setup(String arg, ImagePlus imp) { 
	stack = imp.getStack(); 
	return  DOES_RGB; 
	}
public void run(ImageProcessor ip) {


int w = stack.getWidth();
int h = stack.getHeight();
int dimension = w*h;

float[] X = new float[dimension];
float[] Y = new float[dimension];
float[] Z = new float[dimension];

int[] px =(int[]) stack.getPixels(1);

double R = 0.0;
double G = 0.0;
double B = 0.0;

for (int i=0;i<dimension;i++) {

	R = (double) ((px[i]>>16)&0xff)/255.0;
	G = (double) ((px[i]>>8)&0xff)/255.0;
	B = (double) (px[i]&0xff)/255.0;

//linearise
	if(R <= 0.04045)
		R = R/12.92;
	else R = Math.pow( (R + 0.055)/1.055, 2.4);

	if(G <= 0.04045)
		G = G/12.92;
	else G = Math.pow( (G + 0.055)/1.055, 2.4);

	if(B <= 0.04045)
		B = B/12.92;
	else B = Math.pow( (B + 0.055)/1.055, 2.4);

// convert to XYZ under D65
	X[i] = (float) ((0.4124564*R + 0.3575761*G + 0.1804375*B)/0.950469971);
	Y[i] = (float) ((0.2126729*R + 0.7151522*G + 0.0721750*B)/1.000000119);
	Z[i] = (float) ((0.0193339*R + 0.1191920*G + 0.9503041*B)/1.088829994);
}



ImageStack outStack = new ImageStack(w, h);
outStack.addSlice("X", X);
outStack.addSlice("Y", Y);
outStack.addSlice("Z", Z);
new ImagePlus("CIE XYZ", outStack).show();

}
}
