#TTLocationHandler

This is the evolution of my experimentation and testing the best manner of use of location services in iOS. It started with a base derived from the code and all that I learned from a series by Mark at The Long Weekend Website.

You can find that blog, and the original classes here:
http://longweekendmobile.com/2010/06/30/location-region-data-in-background-on-ios4-iphone/

That code was released "via an MIT-style license (=do whatever you want with it, but don't blame me, and include my copyright notice in the code if you change/redistribute/use)." Everything in the TTLocationHandler class files follow suit and full credit is given to Long Weekend, LLC for helping to get my own understanding of location handling off the ground.

In this repository, you will find one class header and implementation that you want to import if you intend to try it in your own project. The entire class is comprised of the files TTLocationHandler.h and TTLocationHandler.m. The other classes are all just a quick mashup to demonstrate use and check that all works as intended.

##Event Handling Notes:  
- Handler receives the location events from the locationManager, checks for accuracy and time since last event.  
- If the last event was stored a set interval earlier, and is within the required accuracy, the location info is accepted and saved.  
- Saving a location from a location event is done in a property of the handler and in the standardUserDefaults. Saving in the defaults allows any class in the project to get the most recent location without having to import, hold reference to, or even to know anything  at all about the locationHandler class.  
- If the time since previous saved event is outside our parameters and the new location is inaccurate, it is stored in a queue array and considered for acceptance only if another more accurate location isn't received. Ten seconds is allowed to wait for more accurate event, and max tries of 10 before giving up and best available is accepted. 

##Power usage and Background Operation Notes:  
- The default is allow continuous updating of location when the application is in foreground. This can be set on or off.  
- The default is to switch to significantUpdates only when in the background. There is a setting for continuous updates in background when the device is plugged into external power. 
- You can also set continuesUpdatingOnBattery. Use this responsibly as it will impact batter life considerably.  
- The locationManager distanceFilter is increased at highway speeds as events come in scary fast and it seems a waste of activity.  
- Make note of the backgroundTaskIdentifier assignment. The operations were very unreliable before I included this. I recommend using the begin and end task lines where ever you address responding to the location notification. I also recommend putting those operations on a global queue.  

##
All of the paramaters are configurable including accuracy required, distance between location events, max tries for accuracy, wait time for accuracy, continue in background, highway mode. I have tried many variations and the defaults here are what I have had  the best results with.  
My experience, in testing on several devices, is very little impact on battery life and reliable tracking with no serious issues. I am interested to see what improvement might be made by others.  
Please fork and add your input. Any ideas will be considered for push. My aim is to improve what I have and share it for all interested.