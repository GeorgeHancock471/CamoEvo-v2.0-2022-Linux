import ij.*;
import ij.plugin.filter.ExtendedPlugInFilter;
import ij.plugin.filter.PlugInFilterRunner;
import ij.plugin.filter.RankFilters;
import ij.plugin.filter.GaussianBlur;
import ij.gui.DialogListener;
import ij.gui.GenericDialog;
import ij.process.*;
import ij.util.StringSorter;
import java.awt.*;
import java.util.Vector;

/** This ImageJ plugin filter applies an alpha channel *immediately after*
 * a filter or paste operation. The output is a blend of the original and
 * the result of the filter/paste operation preceding the call of this
 * plugin, with the weight of the filtered/pasted image given by an
 * "alpha channel" image.
 *
 * - The 'Alpha Channel' image must have the same size as the current image
 *	 and be either an 8-bit or a float (32-bit) image.
 *	 A value of 0 reverts to the unfiltered/unpasted state; a value equal to
 *   the 'range' (see below) keeps the result of the last filter/paste operation.
 *	 Values in between result in a weighted average of the two image states.
 *
 * - 'Range of Alpha Channel' defines the range of the alpha channel pixels
 *	 (not taking any value calibration into account). In other words, the
 *	 filtered/pasted image is transparent if the alpha channel is 0 and fully
 *	 opaque if the alpha channel is 100%.
 *	 Use a range larger than the actual pixel range to make the filtered/pasted
 *	 image transparent even in places where the alpha channel reaches its maximum
 *	 value.
 *
 * The alpha channel can be modified before applying it:
 * - 'Enlarge by' increases the area by up to 20 pixels. Enter a negative number
 *	 to shrink it. See Process>Filters>Show Circular Masks for the kernel sizes
 *	 as a function of this value.
 * - 'Smooth Radius' is the radius (standard deviation) of a Gaussian blur
 *	 filter applied to the alpha channel.
 *
 * - Use 'Preview' to examine the outcome of the operation.
 *
 * Notes:
 * - Use this plugin immediately after the filter/paste operation.
 * - Do not bring the alpha channel or any other image to the foreground before
 *	 running this plugin, otherwise the undo buffer (snapshot), i.e., all 
 *	 information on the state before the filter/paste operation will be lost!
 * - After running this plugin, undo still reverts to the state before the previous
 *	 filter/paste operation.
 * This plugin does not work for operations that have been applied to stacks.
 *
 * Version 2013-06-25 Michael Schmid: Adapted for ImageJ 1.47a and later;
 *                                    no deprecation or override warnings
 *                                    enlarge/shrink range extended to 50 pxl
 */

public class Alpha_Channel implements ExtendedPlugInFilter, DialogListener {
	private static int FLAGS = DOES_ALL | FINAL_PROCESSING;
	static String alphaName = "";	//name of the 'alpha channel' image
	static float range = 255;		//highest value of the alpha channel
	static double rSmooth = 0;		//radius of Gausian Blur 
	static double rEnlarge = 0;
	ImageProcessor snapshot;		//the snapshot before running this plugin
	boolean canceled;				//will be set if canceled

	/**
	 * This method is called by ImageJ for initialization; also at the very end
	 * (because we have specified the FINAL_PROCESSING flag)
	 * During initialization, we get the snapshot, i.e., the state of the image
	 * preceding the last filter/paste operation.
	 * Note that the snapshot might be modified at a later stage, so it cannot be
	 * used any more after the initial 'setup' call.
	 */
	public int setup (String arg, ImagePlus imp) {
		if (IJ.versionLessThan("1.47a"))	// generates an error message for older versions
			return DONE;
		if (arg.equals("final")) {			// after processing: reset snapshot buffer
			imp.getProcessor().setSnapshotPixels(snapshot.getPixels());
			return DONE;
		}
		if (imp != null) {					// get the current contents of the snapshot buffer
			ImageProcessor ip = imp.getProcessor();
			int width = ip.getWidth();
			int height = ip.getHeight();
			Object snapshotPixels = ip.getSnapshotPixels();
			if (ip != null && snapshotPixels != null) {
				ImageProcessor tempSnapIp = ip.createProcessor(width,height);
				tempSnapIp.setPixels(snapshotPixels);
				snapshot = tempSnapIp.duplicate();	  //we need a clone; snapshotPixels will be modified
			}
		}
		return FLAGS;
	}

	public int showDialog (ImagePlus imp, String command, PlugInFilterRunner pfr) {
		if (snapshot == null) {
			IJ.error(command+" Error", "No previous filter/paste operation\n"+
					"that could be modified by an alpha channel.");
			return DONE;
		}
		String[] suitableImages = getSuitableImages(imp);  // images that we can use as alpha channel for the current one
		if (suitableImages == null) {
			String type = imp.getBitDepth()==24?"RGB":"grayscale";
			IJ.error(command+" Error", "No suitable image (8-bit or float, "+
					imp.getWidth()+"x"+imp.getHeight()+") to use as alpha channel");
			return DONE;
		}
		GenericDialog gd = new GenericDialog(command+"...");
		gd.addChoice("Alpha Channel", suitableImages, alphaName);
		gd.addNumericField("Range of Alpha Channel: 0...", range, 0);
		gd.addNumericField("Enlarge by", rEnlarge, 2, 6, "pixels (-50...50)");
		gd.addNumericField("Smooth Radius", rSmooth, 2, 6, "pixels");
		gd.addPreviewCheckbox(pfr);
		gd.addDialogListener(this);
		gd.showDialog();
		if (gd.wasCanceled()) {
			canceled = true;				// we will leave the unprocessed state, but finally revert the snapshot
			return FLAGS;
		}
		IJ.register(this.getClass());		// protect static class variables (parameters) from garbage collection
		return FLAGS | KEEP_PREVIEW;
	}

	public boolean dialogItemChanged (GenericDialog gd, AWTEvent e) {
		alphaName = gd.getNextChoice();
		range = (float)gd.getNextNumber();
		rEnlarge = gd.getNextNumber();
		rSmooth = gd.getNextNumber();
		return !gd.invalidNumber() && range>0 && rEnlarge>=-50 && rEnlarge<=50 && rSmooth>=0;
	}

	public void run (ImageProcessor ip) {
		if (canceled) return;
		ImageProcessor alpha = WindowManager.getImage(alphaName).getProcessor();
		boolean preprocess = rEnlarge!=0 || rSmooth>0;
		if (preprocess) {						//copy of alpha channel for preprocessing
			alpha = alpha.duplicate();
		}
		if (rEnlarge!=0) {
			if (alpha instanceof ByteProcessor)
				alpha = alpha.toFloat(0, null);
			RankFilters rf = new RankFilters();
			rf.setNPasses(2);
			rf.rank(alpha, Math.abs(rEnlarge), rEnlarge>0 ? RankFilters.MAX : RankFilters.MIN);
		}
		if (rSmooth>0)
			new GaussianBlur().blurGaussian(alpha, rSmooth, rSmooth, 0.01);
		//new ImagePlus("alpha", alpha).show();
		byte[] alphaBytes=null; float[] alphaFloats=null;
		if (alpha instanceof ByteProcessor)
			alphaBytes = (byte[]) alpha.getPixels();
		else
			alphaFloats = (float[]) alpha.getPixels();
		FloatProcessor fp=null, fpSnap=null;	  // non-float images will be converted to these
		for (int i=0; i<ip.getNChannels(); i++) { //grayscale: once. RBG: once per color, i.e., 3 times
			IJ.showProgress((double)i/ip.getNChannels()*(preprocess ? 0.5:1) + (preprocess ? 0.5:0));
			fp = ip.toFloat(i, fp);				  // convert image or color channel to float (unless float already)
			fpSnap = snapshot.toFloat(i, fpSnap); // also convert the previous state (snapshot)
			float[] fPixels = (float[])fp.getPixels();
			float[] fSnapPixels = (float[])fpSnap.getPixels();
			float weight = 0;
			for (int p=0; p<fPixels.length; p++) {
				weight = (alpha instanceof ByteProcessor) ? alphaBytes[p]&255 : alphaFloats[p];
				weight /= range;
				if (weight > 1) weight = 1;
				if (weight < 0) weight = 0;
				fPixels[p] = weight*(fPixels[p]-fSnapPixels[p]) + fSnapPixels[p];//weight*fPix+(1-weight)*fSnapPix
			}
			ip.setPixels(i, fp);				  // convert back from float (unless ip is a FloatProcessor)
		}
	}

	/** Set the number of calls of the run(ip) method. This information is
	 *	needed for displaying a progress bar; unused here.
	 */
	public void setNPasses (int nPasses) {}

	/**
	 * Get a list of open 8-bit and float images with the same size
	 * @return A sorted list of the names of the images. Duplicate names are listed only once.
	 */
	String[] getSuitableImages (ImagePlus imp) {
		int width = imp.getWidth();			 // determine properties of the current image
		int height = imp.getHeight();
		int[] fullList = WindowManager.getIDList();//IDs of all open image windows
		Vector<String> suitables = new Vector<String>(fullList.length); //will hold names of suitable images
		for (int i=0; i<fullList.length; i++) { // check images for suitability, make condensed list
			ImagePlus imp2 = WindowManager.getImage(fullList[i]);
			int bitDepth = imp2.getBitDepth();
			if (imp2.getWidth()==width && imp2.getHeight()==height &&
					(bitDepth==8 || bitDepth==32)) {
				String name = imp2.getTitle();	// found suitable image
				if (!suitables.contains(name))	// enter only if a new name
					suitables.addElement(name);
			}
		}
		if (suitables.size() == 0)
			return null;						// nothing found
		String[] suitableImages = new String[suitables.size()];
		for (int i=0; i<suitables.size(); i++)	// vector to array conversion
			suitableImages[i] = (String)suitables.elementAt(i);
		StringSorter.sort(suitableImages);
		return suitableImages;
	}
}
