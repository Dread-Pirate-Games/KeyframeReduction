# KeyframeReduction
Reduce the size of animations produced via motion capture (e.g. Mixamo) by removing duplicate keyframes

#Background
Using tools like Mixamo is great for getting realistic, potentially complex animations for NPCs. However, they use motion capture to create the animations, which creates a TON of keyframes and poses, even when there's essentially no difference from one frame to the next. This causes bloat in the memory used by your game and causes a rapid rise in the number of instances managed by your game.

So what I did was I wrote a PowerShell script to read the exported animation (.rbxmx file), and then starting at the beginning of the time sequence, move forward and compare the part positions in each sequential keyframe and determine if it had moved enough to warrant a new keyframe. If not, that entry is removed. It goes through the entire animnation part by part, comparing CFrames with a precision of 0.01. Any movement less than that amount is considered discardable.

Why PowerShell and not a Studio plugin? Easy - the instances of keyframes and Poses within Studio do not expose all of the actual position properties that are available in the exported RBXMX file. So it's not physically possible within Studio. Exporting the animation as an RBXMX is simple enough, and re-importing the modified file is also simple. The hardest part for most people using this tool will be using PowerShell :)

#Results
I have achieved anywhere from 15% to 50% reduction in the size of animations this has been run against, with appreciable loss in quality of the animation itself. Greater reductions are achieved when there is relatively little motion for most of the character such as an idle animation. Lower reduction percentages happen when there is a lot of motion of all of the parts of the character, such as shaking.

Note that reducing the overall number of animated part keyframes in your animation can also have the effect of actually letting you edit it in the Roblox animation editor. When you have too many keyframes in an animation, the editor simply draws a line all the way across for the part, rending it just about un-editable. As you'll see from the examples below, reducing keyframes can help you overcome this.

#Examples:

##Idle animation - previous version with 1594 instances
![image](https://user-images.githubusercontent.com/82744105/134259489-8d94f4bb-4517-4548-85f3-5e0639063810.png)

##Idle animation - new version with 991 instances (38% reduction)
![image](https://user-images.githubusercontent.com/82744105/134259528-1e1d8076-ce7d-45cb-98c5-511cb1119a06.png)


##Old animation with 6,283 instances
![image](https://user-images.githubusercontent.com/82744105/134259710-60caae3b-0e89-4df9-9c60-b9e442a1c9e1.png)


##New Animation with 3,653 instances (42% reduction)
![image](https://user-images.githubusercontent.com/82744105/134259753-3ef4173c-089f-4180-9a05-d0797322a947.png)




