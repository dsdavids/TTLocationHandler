TTLocationHandler

This is the culmination of my experimentation and testing of best use of location services in iOS. It started with a base derived from the code and all that I learned from a series by Mark at The Long Weekend Website.

You can find that blog, and the original classes here:
http://longweekendmobile.com/2010/06/30/location-region-data-in-background-on-ios4-iphone/

That code was released "via an MIT-style license (=do whatever you want with it, but don't blame me, and include my copyright notice in the code if you change/redistribute/use)." Everything in the TTLocationHandler class files follow suit and full credit is given to Long Weekend, LLC for getting my own understanding of location handling off the ground.

In this repository, you will find one class header and implementation you want to import it if you intend to try it in your own project. That is the TTLocationHandler.h and TTLocationHandler.m. The other classes are all just a quick mashup to demonstrate use and check that all works as intended.

Event Handling Notes:  
-Handler receives the location events from the locationManager, checks for accuracy and time since last event.  
-If the last event was stored a set interval earlier, and is within the required accuracy, the location info is accepted and saved.  
-Saving a location from event is done in a property of the handler and in the standardUserDefaults. Saving in the defaults allows any class in the project to get the most recent location without having to import, hold reference to, or even to know anything  at all about the locationHandler class.  
-If the duration is outside our parameters and the location is inaccurate, it is stored in a queue array and considered for acceptance only if another more accurate location isn't received. Ten seconds is allowed to wait for more accurate event, and max tries of 10 before giving up and best available is accepted.  

Power usage and Background Operation Notes:  
-The default is allow continuous updating of location when the application is in foreground. This can be set on or off.  
-The default is to switch to significantUpdates only when in the background. There is a setting for continuous updates in background when the device is plugged into external power.  
-The locationManager distanceFilter is increased at highway speeds as events come in scary fast and it seems a waste of activity.  

What I have experienced in testing on several devices is very little impact on battery life and reliable tracking with no serious issues. I am interested to see what improvement might be made by others. Please fork and add your input. Any ideas will be considered for push.