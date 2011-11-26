# Catalyst::Controller::Imager #

generate scaled or mangled images by allowing verbose URIs.

A typical URI looks like

    http://yoursite.tld/image/ <modifier> / path/to/image.ext

where modifier can be a simple rule like

 * h-42

   if you like to get the image scaled to 42 px

 * w-200

   for width scaling

 * h-200-w-200

   if both is wanted

 * thumbnail

   to get a thumbnail image of configurable size

 * foo

   choose names you like and define what should happen behind the curtain

 * thumbnail-blur-9

   any combination of rules and parameters is allowed


Every image is calculated on-the-fly and optionally cached for faster access
next time.
