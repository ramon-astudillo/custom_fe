custom_fe
=============

HCopy_UP is a bash wrapper for a custom front-end usable with HTK and Kaldi. It
imitates HCopy's functionality but calls Matlab or Python code instead. This
allows to easily create custom front-ends that write the features in HTK 
format and can be therefore incorporated to the multiple HTK/Kaldi recipes
available with minor changes.

Since the wrapper is in bash, its use is limited do unix and cygwin 
envrionments. Note however that both pure Matlab MCopy and pure Python (not 
available yet) HCopy wrappers are also provided. These should work also in 
Windows. See the Matlab case as an example.

The wrappers also support observation uncertainty techniques. Patches are also
provided to implement Uncertainty Decoding and Modified Imputation in HTK.

**Instalation of Matlab Tools**

The wrapper makes use of two external toolboxes, the voicebox toolbox and the 
stft_up_tools. Both are downloaded automatically by using

    ./custom_fe/install

This uses wget which depending on your platform might not be available. The
script will ask you to download them with a browser in this case. Note also 
that, from the voicebox toolbox, only the writehtk.m function is used.  

If matlab is available on your bin, this should be enough. If not, you can edit
HCopy_UP and set the MATLAB_PATH variable pointing to your binary.

**Test Using the GRID-DIRHA Baseline Front-End**

As an example, the Matlab front-end for the DIRHA-GRID corpus baseline
is here provided. This front-end is also able to read DIRHA-corpora meta-data
allowing to perform various oracle knowledge experiments, like e.g. Oracle
beamforming or Oracle Voice Activity Detection on DIRHA-corpora, see

    [1] M. Matassoni, R. F. Astudillo, A. Katsamanis, M. Ravanelli "The DIRHA-GRID corpus: baseline 
    and tools for multi-room distant speech recognition using distributed microphones", Interspeech 
    2014

Once the Matlab tools are instaled you can do a test run with

    ./custom_fe/HCopy_UP MAT -C ./custom_fe/MAT/custom/IS2014/config_IS2014 \
                         ./custom_fe/MAT/stft_up_tools/DATA/s29_pbiz6p.wav \
                         ./s29_pbiz6p.mfc \
                         -debug

Note that HCopy_UP will inidicate the coresponding -debug call using only
MCopy.m. This is much faster as it can be done inside Matlab multiple times
to debug a custom front-end. Remember to put a breakpoint in MCopy before the 
exit or it will close Matlab after each run!.

**Using Features with Observation Uncertainty**

HCopy_UP can be used together with front-ends that produce not only features but also a measure of uncertainty. For example for the front-end above this can be attained using the -up flag.  

    ./custom_fe/HCopy_UP MAT -C ./custom_fe/MAT/custom/IS2014/config_IS2014 \
                         ./custom_fe/MAT/stft_up_tools/DATA/s29_pbiz6p.wav \
                         ./s29_pbiz6p.mfc \
                         -up

The additional uncertainties are appended to the normal features resulting in twice the number of features. To process this aditional features with HTK to compute Uncertainty Decoding or Modified Imputation, the patches found [here](http://www.astudillo.com/ramon/research/stft-up/) can be used.

