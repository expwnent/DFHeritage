Dwarven Heritage Project
Author: expwnent

============================================================================
Introduction:

In vanilla DF, last names are randomized. Dwarves do not inherit the last names of their ancestors. I just finished writing an lua script that changes that. It works on both historical figures and the dwarves in the current fort.

Here's the rules of the new system, in no particular order:

1. Suppose parent1 and parent2 have a child. The four possible last names for it are parent1.lastname1, parent1.lastname2, parent2.lastname1, and parent2.lastname2. The child inherits two of these names based on a pattern to be described later. The names inherited by the child depend on the child index of the child (first-born, second-born, etc), and the age of the names in question.

2. A name is considered to be "born" when it is FIRST used. Even if the first dwarf to have that name is dead, it still counts. Dwarves that were born before year 0 count. A name can be older than the world. Nothing special happens with that, though.

3. Let the four names in question of a dwarf and its spouse be A,B,C and D. First, sort these names based on age (of name), breaking ties alphabetically. Let's call sorted names, in order 1,2,3 and 4. The child last name pattern is (1 2), (1 3), (1 4), (2 3), (2 4), (3 4), then it repeats. This pattern is designed to make older names more frequent, leading to a small number of common last names.

4. No dwarf can have the same last name twice.

5. No dwarf can have the same full name as another dwarf.

6. A dwarf with no parents, or one with parents who are lost to history, must have both last names be unique.

7. In the event of a conflict due to the previous rules, the dwarf in question's second last name is randomly assigned to a new, unused last name until the conflict is resolved. This (should be) the only way new last names are created, other than the starting 7 dwarves in a fort.

8. Note that last names of dwarves will always be sorted in order of name age. Older last names will always come before younger last names.

9. Also note that gender is not taken into account, including gender of parents.

10. These rules apply only to dwarves. More accurately, they apply only to the primary race of the current fort.

11. In the event that there are so many dwarves that not all of them can have unique names, the system just gives up and allows repeats.

============================================================================
Possible improvements: I've considered giving royalty a special extra last name, like what happens with dwarves that kill a lot of enemies. This extra last name would always be passed on unless there's a conflict, so you can tell which dwarves are descended from a monarch, and if so, which ones. The only problem is I don't know how to determine who was a civilization leader and when in lua. Advice on this is very welcome. Doing the rest of it shouldn't be that hard.

============================================================================
Troubleshooting:

1. Save first. Keep a backup. You don't want to lose a save over this (though I never have).

2. In earlier versions, there was a problem where DFTherapist would crash after running this plugin, but saving and reloading the world fixed it.

3. It might mess up legends a little, especially with the names of leaders.

4. It's possible that it will print names and sort them alphabetically based on the wrong language. All of my language files are the same, so I didn't bother checking.

5. It works best if you do NOT cull unimportant historical figures, for obvious reasons.

6. Sometimes it confuses LegendsViewer into thinking that some dwarves are the same. I suspect this is because their last names don't have the right part of speech, and so they are treated as nonexistant. It should work fine in-game.

============================================================================
Thoughts:

A dwarf doesn't necessarily share a last name with a sibling, or even a parent.

This mod does not change any gameplay mechanics, but I think it adds some very interesting flavor to the game. Every dwarf has exactly two Families, one for each last name. In theory, the game should only generate only as many Families as necessary to prevent repeated last names, but I've seen it generate quite a few.

============================================================================
Installation:

Requires DFHack. Was written for DFHack 0.34.11 r1. Install that or a later version first.

The script itself is probably horribly illegible, but it should work. Just put it in hack\scripts\heritage.lua and run it with "lua hack/scripts/heritage.lua". Load a save in dwarf mode first. I haven't tried in adventure mode or legends mode, but I predict that it would do something between working fine and causing the apocalypse.

After running, it should output all the last names that are present in your fort (among the living), oldest names first.

You will, of course, need to rerun the script any time a dwarf has children in your fort. Fortunately, the script is very fast.
