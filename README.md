custom_fe
=============

HCopy_UP is a bash wrapper for a custom front-end usable with HTK and Kaldi. It
imitates HTK's HCopy interface but calls Matlab or Python code internally. This
allows to easily create custom front-ends that write the features in HTK or 
Kaldi format and can be therefore incorporated to the multiple HTK/Kaldi recipes
available with minor changes. 

The wrapper is written in bash, thus limited do unix and cygwin environments. 
Note however that the bash wrapper calls pure Matlab MCopy and pure Python 
HCopy wrappers internally. These should also work in Windows.

I created HCopy_UP as a way to unify my multiple front-ends for uncertainty 
propagation and observation uncertainty techniques. The wrappers therefore 
support these techniques in a plug-and-play fashion. Right now following 
examples are available 

* STFT-UP used to derive a MMSE-MFCC estimator and its residual uncertainty
* Sparsity based Uncertanties as those used in CHiME 2013 challenge
* The DIRHA-GRID front-end for interspeech 2014

You can have a look here for more details

    https://github.com/ramon-astudillo/stft_up_tools

Patches are also provided to modify HTK 3.4.1. in order to be able to process
these uncertainties using Uncertainty Decoding and Modified Imputation. 

*Support for Kaldi*

The support for Kaldi format features files is already included in the install,
via the kaldi-to-matlab toolbox. You just need to set TARGETFORMAT to KALDI in 
a config file (default being HTK). Note that you need the Kaldi binaries to be 
available and some other pre-requisites. This is also relatively new so I
appreciate feedback for debugging platform issues. 

There are also tools by other authors that can be combined with this toolbox e.g.
integration with Kaldi. Have a look at the Robust Speech Processing Special 
Interest Group (RoSP) WiKi

    https://wiki.inria.fr/rosp/Software

*Support for Python* 

Feature extractions are the only part of my code-base that has survived in Matlab
despite my switch to Python a while ago. There is already a Python front-end
with uncertainty propagation and IMCRA available in this public version, 
although it has not been tested thoroughly. I expect Python to slowly eat up
Matlab's share of code in this repo.
    
**Instalation of Matlab Tools from the zip**

If you are familiar with Git, the best way to use these tools is to fork and 
clone the repo from Github. The other alternative is to download the zip 
manually (right side of the screen on Github). In that case you can rename the
unzipped tools as

    mv ./custom_fe-master ./custom_fe

It should work anyway, it is more a matter of aesthetics.

The wrapper makes use of various external toolboxes, Mike Brooke's voicebox 
toolbox, Emmanuel Vincent's kaldi-to-matlab toolbox and my stft_up_tools and 
obsunc toolboxes. They are downloaded automatically by using

    ./custom_fe/install

This uses wget, which depending on your platform might not be available. The
script will ask you to download them with a browser in this case. Note also 
that only the needed functions are unzipped.   

If matlab is available on your bin, this should be enough. If not, you can edit
HCopy_UP and set the MATLAB_PATH variable pointing to your binary.

**Test Using the GRID-DIRHA Baseline Front-End**

As an example, the Matlab front-end for the DIRHA-GRID corpus baseline
is here provided. This front-end is also able to read DIRHA-corpora meta-data
allowing to perform various oracle knowledge experiments, like e.g. Oracle
beamforming or Oracle Voice Activity Detection on DIRHA-corpora, see

    [1] M. Matassoni, R. F. Astudillo, A. Katsamanis, M. Ravanelli "The DIRHA-GRID corpus: 
    baseline and tools for multi-room distant speech recognition using distributed 
    vmicrophones", Interspeech 2014

Once the Matlab tools are instaled you can do a test run with

    ./custom_fe/HCopy_UP MAT -C ./custom_fe/MAT/custom/IS2014/config_IS2014 \
                         ./custom_fe/MAT/stft_up_tools/DATA/s29_pbiz6p.wav \
                         ./s29_pbiz6p.mfc \
                         -debug

Note that HCopy_UP will indicate the corresponding -debug call using only
MCopy.m. This is much faster as it can be done inside Matlab multiple times
to debug a custom front-end. Remember to put a breakpoint in MCopy before the 
exit or it will close Matlab after each run!.

**Using Features with Observation Uncertainties**

HCopy_UP can be used together with front-ends that produce not only features 
but also a measure of uncertainty. For example for the front-end above this 
can be attained using the -up flag together with the config using the MMSE-MFCC 
estimator (config_IS2014M) as 

    ./custom_fe/HCopy_UP MAT -C ./custom_fe/MAT/custom/IS2014/config_IS2014M \
                         ./custom_fe/MAT/stft_up_tools/DATA/s29_pbiz6p.wav \
                         ./s29_pbiz6p.mfc \
                         -up

The additional uncertainties are appended to the normal features resulting in 
twice the number of features. To process this aditional features with HTK to 
compute Uncertainty Decoding or Modified Imputation, the patches found 
[here](http://www.astudillo.com/ramon/research/stft-up/) can be used.
