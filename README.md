UIView+MWParallax
=================

Parallax UIView category which can be used in iOS prior to 7 (tested with iOS 6.1)

It's as simple as setting UIView's (or it's any subclass) param iOS6ParallaxIntensity value to any other than 0.

For example:

    self.label = [[UILabel alloc] init];
    ...
    self.label.iOS6ParallaxIntensity = 15;

To use this you need to include CoreMotion.framework to your project.

This currently works only with ARC!

<img src="http://imageshack.us/a/img51/2786/84h.gif"/>
