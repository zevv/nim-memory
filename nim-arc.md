
= Nim ARC
:toc: left
:toclevels: 4
:icons: font
:doctype: book
:stylesheet: style.css
:nofooter:

== Introduction

Blah blah ARC

`--gc:arc`


== Garbage collection

part I of this document, "The Nim Memory Model", introduced the two pointer
types available in Nim:

- The `ref` type: This is a _managed pointer_, which points to memory that Nim
  will free for you when it is no longer needed. This is almost always the kind
  of pointer you want to use, unless you have good reasons not to. The only way
  to create a pointer of the `ref` type is by using `new()` to construct an
  object or a variable of a given type on the heap.

- The `ptr` type: This is an _unmanaged pointer_, pointing to data that the
  user needs to allocate and deallocate manually, as if you were programming C
  using `alloc()` and `free()`

Refs are originally managed in Nim by a _garbage collector_, or _GC_ in short.

There are many types of garbage collectors, but basically they all operate in a
similar way: every now and then your program is briefly interrupted, and the
garbage collector takes control. It will then look at allocated blocks in
memory and try to find which of these are no longer in use, e.g, there are
no longer any pointers referencing that block. When a block is found that
no one is pointing to, the GC knows it is safe to free it.

GC's are cool because they release the programmer of the burden of keeping
track of memory, typically leading to safer code (no free-after-use) and less
memory leaks.

There are some downsides to using a GC however:

- Garbage collection is a process that has to be run periodically, and takes
  time to do so. This might interfere with your application - you probably do
  not want the GC to start doing its work for 20msec when you are drawing video
  frames at 60fps in your video game.

- Garbage collectors are often non-deterministic: you as a programmer are not
  in control of exactly when a resource is cleaned up, you can not say "I want
  this memory to be freed _now_"

- The code for doing the garbage collection needs to be part of your program.
  This is usually not a problem for desktop or server applications, but for
  small embedded targets this can be considerable overhead.

- Garbage collectors do not play nice with threads. TODO Elaborate on this


== Introducing: ARC

With Nim version 1.2, a new model for memory management was introduced, called
_ARC_. With ARC, the compiler got much smarter about memory, so that garbage
collection is no longer needed.

ARC manages your memory in a totally different way than a garbage collector does.
Instead of periodically interrupting the program and scan for unreferenced memory,
ARC builds on a number of other concepts:

- Reference counting
- Destructors
- Move semantics

These points will be elaborated on in the next sections.


=== Reference counting

With ARC, Nim will keep track of some additional data for each managed memory
block. Part of this data is the _reference count_ (also called _refcount_, or
_rc_) of the memory block. The refcount simply is a integer which keeps track
of _how many pointers to the memory block_ exist. Nim will make sure this
counter is increased every time a pointer is copied, and decreased every time a
pointer is "lost". You can lose a pointer for example when it goes out of
scope, or when it was stored in another object that is itself destroyed.

When the last pointer to an object goes away, the reference counter will drop
to 0. This means that no one is referencing this memory block anymore, so it
Nim knows it can now free this block. It does this with the help of a
_destructor_.


=== Destructors

A _destructor_ is a proc that gets called by Nim when the reference counter
drops to 0. Every type has its own destructors, the compiler will generate
default destructors for you that do the right thing if you do not define one.

Destructors are implemented by a proc called `=destroy` and look like this:

----
proc `=destroy(x: var T)
----


TODO: tell about what a destructor should do


=== Move semantics

The above two concepts are basically all that is needed for managing memory:
keep track of how many pointers reference a block, and free the block when
there are no more references. 




