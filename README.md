# BurstParticles2D

Make cool, chunky one-shot particle effects with textures, curves and gradients. BurstParticles2D uses GDScript, RenderingServer and tweens so it is not as fast as built-in particle solutions, but has finer control and some features that Godot lacks out of the box.

https://user-images.githubusercontent.com/43023911/231001149-7ffd5313-05b3-41d2-aa5c-a6a6d7c090fc.mp4

https://user-images.githubusercontent.com/43023911/231001094-9b568a51-ff4b-40bb-8ef7-9709d101b164.mp4

To install, place into your addons folder and activate the plugin.

Check out the example scene to see how this node is used. Most of the time you can simply instantiate and place the node somewhere and it will handle freeing itself on its own. You can use the BurstParticleGroup2D node to layer multiple BurstParticles for more complicated effects. If you get stutters when instancing lots (hundreds or thousands) of particles at once, try turning on the "shared material" parameter.
