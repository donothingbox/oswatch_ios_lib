oswatch_ios_lib
===============

This is the home for the initial OSWatch iOS app. Eventually this will hold the abstract Libs, with demo apps being seperate.


NOTES: 

1.) NEAR FUTURE PLANS — Code needs more cleanup and a bit better explanations as to what is going on. It works in it’s current version, and I wanted to migrate to GitHub quickly.

Currently this is a full Xcode project. Once it’s more stable, I will move the xCode project to a separate location, and just keep the Core Libs here. 

The current Library Files are:

BLEConnectionDelegate.h
BLEConnectionDelegate.m
PairedDevice.h
PairedDevice.m

you can run through functionality tests in the ConnectionViewController class. Also, the 3rd tab when you run the app. That should let you test basic connections, and it will give the watch the time. 