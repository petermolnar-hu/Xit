# Xit

Xit (pronounced "exit") is a graphical tool for working with git repositories. The overall goals are:

  * A useful graphical interface for viewing and managing your repository
  * Stability and scalability - handle large repositories well (lots of commits and lots of files)
  * A well-organized codebase to facilitate continued development

# Background and current status

Xit began as a rewrite of GitX, born from a desire for a codebase that was easier to work with, thoroughly unit tested, etc. It is currently working towards 1.0 beta status, where all basic features are in place, with many more interesting features slated for the future.

Currently there are two major transitions underway: consolidating the user interface (originally there were separate history/commit/file tree views), and migrating to Objective-Git instead of the command-line tool.

# Roadmap

The plan is to have a concrete 1.0 milestone to provide a good foundation and firm direction moving forward. Version 1.0 will simply be a starting point covering basic usage:

  * History view graph
  * Sidebar for navigating branches, remotes, tags, and stashes
  * Viewing the diff of a selected commit
  * Basic git actions: staging, committing, remote push/pull

Plenty of advancements are on the post-1.0 list, like syntax highlighting and other diff view enhancements, file history and blame views, etc.

Some other ideas that I’m looking forward to working on (and using!):

  * Interacting with git hosting services (especially GitHub): discovering forks, viewing commits online, working with pull requests
  * Interactive rebase
  * Explore more ways to navigate and visualize the repository

# Development

## Building

The repository uses several submodules, so you will need to clone the repository rather than downloading the source archive. To begin, get the submodules set up with `git submodule update --init --recursive` from the root of the project. You will also need [CMake] to build libgit2, and [Homebrew] for the other libraries used by Objective Git. If you hit any snags, please file an issue.

  [CMake]: http://cmake.org/
  [Homebrew]: http://brew.sh

Note that Objective Git needs the `objective-git/script/boostrap` script to be run to configure everything. If Objective Git is later updated, you may need to re-run the script.

## Contributing

If you're looking for a starter task, several issues have been marked "small". These should provide a relatively easy intro to the code base.

Swift is preferred for new classes, but not necessarily required. In particular, working with some C APIs can be awkward in Swift, so Objective-C is fine. 

For larger tasks, there are two options:

* Plenty of other ideas and plans have been written down in the [Issues] section. Feel free to comment and contribute there.
* Just run the app and see what bugs you!

  [Issues]: https://github.com/Uncommon/Xit/issues

If you decide to start working on something, please add a note in the issue (file a new one if needed). When you're ready to share your work, please follow the usual procedure for a GitHub pull request.

## Coding style

The coding style used is based on the [Google Objective-C Style Guide], with the following changes:

  [Google Objective-C Style Guide]: http://google-styleguide.googlecode.com/svn/trunk/objcguide.xml

* Line length is 80 columns.
* The opening brace of a function goes on its own line.
* No single-line `if` statements, like `if (x) return;` (you can't set a breakpoint on that `return`!)
* No space before `*` when it is not immediately followed by an identifier, such as `(NSString*)`.
* When wrapping function/method calls, a four-space indent may be used instead of aligning with the `:` or `(`.
* Variable declarations are separated from other statements by one blank line.
* Whitespace at the indentation level of the surrounding lines is allowed.
* Doxygen style comments are encouraged because Xcode parses them.
* Explicitly compare values with `0`, `nil`, or `NULL`. Only write `if (x)` if `x` is a Boolean value.

Some of the code was written before these rules were put in place and may still need to be updated. Feel free to correct any instances you find.
