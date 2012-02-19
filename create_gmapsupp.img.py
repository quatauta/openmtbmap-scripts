#!/usr/bin/python

# Written by Rainer Poisel <rainer.poisel@gmail.com>
# Released under the GPLv3 License

import sys
import subprocess
import shutil
import fnmatch
import os, os.path

# commands required:
# * cp thinat.TYP 01002468.TYP
# * wine gmt.exe -wy 7352 01002468.TYP
# * wine gmt.exe -j -o gmapsupp.img -f 7352 -m "openmtbmap_srtm" 6*.img 7*.img 01002468.TYP

class CGeneratorContext(object):
	wine_cmd = 'wine'
	gmt_cmd = 'gmt.exe'

	@staticmethod
	def is_exe(fpath):
		return os.path.exists(fpath) and os.access(fpath, os.X_OK)

	@staticmethod
	def which(program):
		fpath, fname = os.path.split(program)
		if fpath:
			if CGeneratorContext.is_exe(program):
				return program
		else:
			for path in os.environ["PATH"].split(os.pathsep):
				exe_file = os.path.join(path, program)
				if CGeneratorContext.is_exe(exe_file):
					return exe_file

		return None

	def __init__(self):
		if not os.path.exists(CGeneratorContext.gmt_cmd):
			raise Exception(CGeneratorContext.gmt_cmd +
                                        """ not found. Please put gmt.exe into the same folder in which the maps and this batch are placed. Make sure """ +
                                        CGeneratorContext.gmt_cmd +
                                        """ is version 048a or later (gmt.exe included with contourlines download is outdated).
""" +
                                        CGeneratorContext.gmt_cmd +
                                        """ is part of gmaptool which you can download here:
http://www.anpo.republika.pl/download.html#gmaptool
			""")
		self.__mCommandPrefix = []
		if os.name == 'posix':
			if CGeneratorContext.which(CGeneratorContext.wine_cmd) == None:
				raise Exception(CGeneratorContext.wine_cmd +
                                                " needs to be installed to run " +
                                                CGeneratorContext.gmt_cmd + " under POSIX-OSes.")
			self.__mCommandPrefix.append(CGeneratorContext.wine_cmd)

	def run_gmt(self, pArgs):
		lProcess = subprocess.Popen(self.__mCommandPrefix +
                                            [CGeneratorContext.gmt_cmd] +
                                            pArgs,
                                            stderr=subprocess.PIPE)
		return (lProcess.wait(),
                        lProcess.stderr.read())

	def correct_typ(self, pFID, pTarget):
		# wine gmt.exe -wy 7352 01002468.TYP
		self.run_gmt(["-wy", pFID, pTarget])

	def join_maps(self, pFID, pTypefile, pOSMMaps, pSRTMMaps, pType):
		# wine gmt.exe -j -o gmapsupp.img -f 7352 -m "openmtbmap_srtm" 6*.img 7*.img 01002468.TYP

                dirname = os.path.split(os.getcwd())[1]

                if 0 < len(pOSMMaps) and 0 < len(pSRTMMaps):
                        name = "OpenMTBMap %s %s %s %s" % (dirname, pFID, "SRTM", pType)
                elif 0 == len(pOSMMaps):
                        name = "OpenMTBMap %s %s %s %s" % (dirname, pFID, "SRTM only", pType)
                else:
                        name = "OpenMTBMap %s %s %s" % (dirname, pFID, pType)

                print "\n\n" + name + "\n"

		lArgs = ["-j", "-o", "gmapsupp.img", "-f", pFID, "-m", name]
		lArgs += pOSMMaps
		lArgs += pSRTMMaps
                if pTypefile:
                        lArgs.append(pTypefile)
		self.run_gmt(lArgs)

	def generate_gmapsupp(self, pType):
		lTypefile = "01002468.TYP"
		lFID = ""
		lFID_OSM = ""
		lFID_SRTM = ""
		lOSMMaps = []
		lSRTMMaps = []

		# determine FID and Map files
		for lFile in os.listdir('.'):
			if fnmatch.fnmatch(lFile, "6*.img"):
				lOSMMaps.append(lFile)
                                lFID_OSM = lFile[0:4]
			if fnmatch.fnmatch(lFile, "7*.img"):
				lSRTMMaps.append(lFile)
                                lFID_SRTM = lFile[0:4]

		if len(lOSMMaps) > 0 and len(lSRTMMaps) > 0:
			lFID = lFID_OSM
		elif len(lOSMMaps) > 0:
			lFID = lFID_OSM
		elif len(lSRTMMaps) > 0:
			lFID = lFID_SRTM
		else:
			raise NameError("Could not determine FID. No maps present?")

		# find typefile
		lTypFile = ""
		for lFile in os.listdir('.'):
			if fnmatch.fnmatch(lFile, pType + "*.TYP"):
				lTypFile = lFile
		if lTypFile != "":
                        # cp thinat.TYP 01002468.TYP
                        shutil.copyfile(lTypFile, lTypefile)
                        self.correct_typ(lFID, lTypefile)
                        self.join_maps(lFID, lTypefile, lOSMMaps, lSRTMMaps, pType)
                else:
                        self.join_maps(lFID, None, lOSMMaps, lSRTMMaps, pType)

def main():
	try:
		lContext = CGeneratorContext()

	# TODO determine target TYP-file
		print("""
Enter clas for clas*.TYP (classic layout - optimized for Vista/Legend series)
Enter thin for thin*.TYP (thinner tracks and pathes - optimized for Gpsmap60/76 series)
Enter wide for wide*.TYP (high contrast layout, like classic but with white forest - optimized for Oregon/Colorado dull displays)
Enter trad for trad*.TYP Big Screen layout. Do not use on GPS.
	""")

		lTypFile = raw_input("Enter Typefilename (EOF to exit): ")
		lContext.generate_gmapsupp(lTypFile)
	except LookupError,pExc:
		print("Error: " + str(pExc))
		sys.exit(-1)
	except NameError,pExc:
		print("Error: " + str(pExc))
		sys.exit(-2)
	except EOFError,pExc:
		sys.exit(-3)
	except Exception,pExc:
		print("Error: " + str(pExc))
		sys.exit(-4)

	print("""
SUCCESS
gmapsupp.img generated
_
please put gmapsupp.img into folder /garmin/ on your GPS memory (connect your GPS and choose mass storage mode)
or write gmasupp.img directly to memory card into /garmin/ folder (for fast transfer put memory card into a cardreader)
Backup any old gmapsupp.img that was placed there before if it exists already.
Attention, if you want to have address search you have to use Mapsource to send maps to GPS.
	""")

if __name__=="__main__":
	main()

