#!/usr/bin/python

'''
Template for custom feature extraction 
'''

import numpy as np
#import matplotlib.pyplot as plt

import re

# DEBUG
#from ipdb import set_trace

# Add the needed tools
import interfaces.audio as ia        # Read raw 
import interfaces.htk as htk         # Read raw 
import processing.signal as sip      # STFT
import processing.imcra as se        # IMCRA
import processing.features as fe     # MFCCs
import os
# Template for feature extraction
import interfaces.HCo as HCopy 

# SUPPORTED HTK FIELDS AND DEFAULT VALUES IF ADMITTED
HTK_SUPP = {
    'windowsize'   : None, 
    'deltawindow'  : None,
    'accwindow'    : None,  
    'targetkind'   : 'USER', 
    'targetformat' : 'HTK',
    'preemcoef'    : 0.97, 
    'usepower'     : False, 
    'numchans'     : 23,
    'numceps'      : 12, 
    'ceplifter'    : 22,
           }

# ADDITIONALLY NON-HTK SUPPORTED FIELDS AND DEFAULT VALUES IF ADMITTED
EXTRA_SUPP = {
    'fp'              : None,
    'tc'              : None,
    'in_fs'           : None,
    'work_fs'         : None,
    'shift'           : None,
    'nfft'            : None,
    'separate_events' : 0,     
    'byteorder_raw'   : 'littleendian',
    'mmse_method'     : 'LSA',
    'init_time'       : 0.1,
    'do_resume'       : 0,
    'do_debug'        : 0,
    'do_up'           : 0
             }

def validate_config(config):
    '''
    Check that all needed fields are specified and no alien parameters
    '''
   
    # CHECK IF ANY NON SUPPORTED PARAMETER PRESENT
    for key in config:
        if (key not in HTK_SUPP) and (key not in EXTRA_SUPP):
            ValueError, "Unknown config field %s" % key 

    # To write in HTK format
    config['tc'] = HCopy.targetkind2num(config['targetkind']) 
    config['fp'] = float(config['shift'])/config['in_fs'] 

    # FOR THE REST IF DEFAULTS EXISTS USE IT, OTHERWISE RISE ERROR 
    for supp in [HTK_SUPP, EXTRA_SUPP]:
        for key in supp.keys():
            if key not in config:
                if supp[key] is None:
                    raise ValueError, ("You have to provide a value for "
                                       "config field %s") % key
                else:
                    config[key] = supp[key]
    return config

class FE():

    def __init__(self, config):
    
        # Set in_fs to be work_fs if not specified
        if 'in_fs' not in config:
            config['in_fs'] = config['work_fs']  
    
        # Check if all config is correct
        self.config = validate_config(config)

        # Read external VADs if provided
        if 'stm_vad' in self.config:
            self.config['stm_trans'] = aud.readstm2dict(config['stm_vad'])
        elif 'mlf_vad' in self.config:
            # VAD SPECIFIED BY A MLF
            raise NotImplementedError, "Not implemented yet"
    
        # IMCRA
        self.se   = se.imcra_se(config['nfft'])

        # Initialize MFCC coefficients
        self.mfcc =  fe.mfcc(config['work_fs'], config['nfft'], 
                             config['numchans'], config['numceps'], 
                             config['ceplifter'], config['usepower'])
     
    def extract(self, src_file, tgt_file):
        '''
        Feature extraction
        '''
    
        # Read this audio file
        y_t = ia.read(src_file, in_fs=self.config['in_fs'], 
                      out_fs=self.config['work_fs'])[0]

        #
        # BEAMFORMING
        # 

        # Beamformer poiting at the fromtal direction by default
        if len(y_t.shape) > 1 and  y_t.shape[1] > 1:
            y_t = y_t.sum(1)

        #
        # SPEECH ENHANCEMENT
        #            
        
        # Pre-emphasis, STFT
        y_t = sip.preemphasis(y_t, coef=self.config['preemcoef'])
        Y   = sip.stft(y_t, self.config['windowsize'], self.config['shift'], 
                       self.config['nfft'])
        # Compute IMCRA  
        hat_X_LSA = self.se.update(Y)


        if (self.config['mmse_method'] == 'MFCC' or 
            self.config['mmse_method'] == 'Wiener'):

            # Get a priori SNR and noise variance 
            xi, Lambda_D = self.se.get_param(['xi', 'Lambda_D'])
            # Get Wiener estimate and residual MSE
            G     = xi/(1+xi)
            # Use the posterior associated to the Wiener filter
            hat_X = G*Y
            if self.config['mmse_method'] == 'MFCC':
                MSE   = G*Lambda_D 
            else:
                MSE   = np.zeros(G.shape) 

        elif self.config['mmse_method'] == 'LSA':
            
            # Use LSA 
            hat_X = hat_X_LSA
            MSE   = np.zeros(hat_X.shape)

        #
        # FEATURE EXTRACTION / UNCERTAINTY PROPAGATION
        #

        # MFCC
        mu_x, Sigma_x = self.mfcc.extract_up(hat_X, MSE)  
        # CMS
        mu_x, Sigma_x   = self.mfcc.cms_up(mu_x, Sigma_x)
        # Deltas, Accelerations
        mu_d, Sigma_d = fe.deltas_up(mu_x, Sigma_x)   
        mu_a, Sigma_a = fe.deltas_up(mu_d, Sigma_d)   
        mu_x          = np.concatenate((mu_x, mu_d, mu_a))
        Sigma_x       = np.concatenate((Sigma_x, Sigma_d, Sigma_a))

        # Provide uncertainty
        if self.config['do_up']:
            x = np.concatenate((mu_x, Sigma_x))
        else:
            x = mu_x
       
        # Plot features, for debug 
        if self.config['targetformat'] == 'HTK':
            htk.writehtkfeats(tgt_file, x, self.config['fp'], self.config['tc']) 
        else:
            raise ValueError, ("TARGETFORMAT = %s Not supported" 
                               % self.config['targetformat'])
