# BurstParticles2D

Make cool, chunky one-shot particle effects with textures, curves and gradients. BurstParticles2D uses GDScript, RenderingServer and tweens so it is not as fast as built-in particle solutions, but has finer control and some features that they lack.

Check out the example scene to see how this node is used. Most of the time you can simply instantiate and place the node somewhere and it will handle freeing itself on its own. You can use the BurstParticleGroup2D node to layer multiple BurstParticles for more complicated effects. If you get stutters when instancing lots (hundreds or thousands) of particles at once, try turning on the "shared material" parameter.