#!/usr/bin/python

'''
Template for custom feature extraction 
'''

#import ipdb
import numpy as np
#import matplotlib.pyplot as plt

import re

# DEBUG
#from ipdb import set_trace()

# Add the needed tools
import interfaces.audio as ia        # Read raw 
import interfaces.htk as htk         # Read raw 
import interfaces.audimus as aud     
import processing.signal as sip      # STFT
import processing.imcra as ns        # IMCRA
import processing.features as fe     # MFCCs
import os
# Template for feature extraction
import interfaces.HCo as HCopy 

# SUPPORTED HTK FIELDS AND DEFAULT VALUES IF ADMITTED
HTK_SUPP = {
    'windowsize' : None, 
    'deltawindow': None,
    'accwindow'  : None,  
    'targetkind' : 'USER', 
    'preemcoef'  : 0.97, 
    'usepower'   : False, 
    'numchans'   : 23,
    'numceps'    : 12, 
    'ceplifter'  : 22,
           }

# ADDITIONALLY NON-HTK SUPPORTED FIELDS AND DEFAULT VALUES IF ADMITTED
EXTRA_SUPP = {
    'fp'            : None,
    'tc'            : None,
    'in_fs'         : None,
    'work_fs'       : None,
    'shift'         : None,
    'nfft'          : None,
    'byteorder_raw' : 'littleendian',
    'do_resume'     : 0,
    'do_debug'      : 0,
    'do_up'         : 0,
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
        self.se   = ns.imcra_se(config['nfft'])

        # Initialize MFCC coefficients
        self.mfcc =  fe.mfcc(config['work_fs'], config['nfft'], 
                             config['numchans'], config['numceps'], 
                             config['ceplifter'], config['usepower'])
     
    def extract(self, src_file, tgt_file):
        '''
        Feature extraction
        '''
        # Get indices for the position of speech and background based on 
        # external info. If MLF or STM provided for VAD use them.
        if 'stm_vad' in self.config:

            # VAD SPECIFIED BY A STM
            if src_file not in self.config['stm_trans']:
                raise EnvironmentError, ("stm file %s has not transcription "
                                         "for %s" % (self.config['stm_vad'], 
                                         src_file))  
            # Collect speech events and preceeding backgrounds
            events = []
            backgs = []
            t_bg   = 0 
            for tr in self.config['stm_trans'][src_file]:
                # Preceeding background
                if not tr[2]:
                    backgs.append(None) 
                else:
                    backgs.append((0, tr[2]*self.config['in_fs'])) 
                # Speech event
                events.append((src_file, tr[2]*self.config['in_fs'], 
                               tr[3]*self.config['in_fs'])) 
            
 
        else:

            # ONE SINGLE EVENT IN PRESENT MICROPHONE
            if 'T_init' in config:
                events = [(src_file, 0, -1)]  
                backgs = None 
            else:
                events = [(src_file, config['T_init'], -1)]  
                backgs = [(0, config['T_init'])] 

        # Loop over events in the scene
        for backg, event in zip(backgs, events):
     
            # Read this audio file
            y_t = HCopy.read(event[0], self.config['in_fs'], 
                             self.config['work_fs'])

            # Select segment of background preceeding speech 
            if backg:
                d_t = y_t[backg[0], backg[1]]
            else:
                d_t = None

            # Select segment of speech 
            y_t = y_t[event[1]:event[2]] 
        
            # Pre-emphasis, STFT
            y_t = sip.preemphasis(y_t, coef=self.config['preemcoef'])
            Y   = sip.stft(y_t, self.config['windowsize'], self.config['shift'], 
                           self.config['nfft'])


            #
            # SPEECH ENHANCEMENT
            #            


            # MFCC
            x   = self.mfcc.extract(Y)  
            # CMS
            x   = self.mfcc.cms(x)
            # Deltas, Accelerations
            d   = fe.deltas(x)   
            a   = fe.deltas(d)   
            x   = np.concatenate((x, d, a))
       
            # Plot features, for debug 
            HCopy.plot(x)
     
            # Write features
            y_t = HCopy.write(tgt_file, x, self.config['fp'], self.config['tc'])        

            # TODO: Write vad file
