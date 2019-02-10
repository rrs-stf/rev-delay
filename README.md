# Stereo Reverse Delay

Inspired from https://ccrma.stanford.edu/~hskim08/sttr/. Check it out for more details regarding the theoretical aspect of the project.

This is an implementation of a Reverse Delay/Echo plugin, using Short-Time Time Reversal (STTR) with a constant 50% overlap-add method (OLA), for a stereo input. 

## Parameters
Each audio channel is modified using the following parameters: Level, Grain Size, Overtone, Mix and Feedback
- **Level**: controls the level of the input signal
- **Grain Size**: controls length of the reversed sections; ranges between 1ms and 1s

Based of the value of the Delay parameter and due to the unique spectral effects generated from the 50% OLA, the plugin has three modes of operation:

    + Harmonizer: generates additional overtones to the sound (Grain between 1ms and 33ms)
    + Reverb: the plugin creates a reverb-like effect to the audio input (Grain between 33ms and 100ms)
    + Reverse Delay: the normal mode of operation, when the reverse sections are audible (Grain larger than 100ms)
    
It is worth noting that the "Harmonizer" aspect of the plugin is very hard to control, if the aim is to create a certain spectral shape.

- **Overtone**: modifies the amount of overtones when the plugin is used in "Harmonizer" mode; changes the shape of the window applied on the reversed sections, interpolating between a Hann and a rectangular window

- **Mix**: controls the mix between the dry (original input) and wet (output of STTR) signals
- **Feedback**: controls the feedback amount in the delay; the sections are feedbacked in such a way that the output of the plugin will still yield an entirely reversed sound
