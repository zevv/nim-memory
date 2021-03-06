
= Nim ARC
:toc: left
:toclevels: 4
:icons: font
:doctype: book
:stylesheet: style.css
:nofooter:


This is a work in progress. The goal of this document is to make a friendly
explanation of ARC and its implications for the programmer. The target audience
is mixed:

- experience Nim users that have heard of ARC but did not yet try or switch because
  they are not quite sure what all the fuzz is about

- not-yet expert Nim programmers coming from languages like Python or C++ and
  want to know how stuff is done in Nim

The source of this document can be found at https://github.com/zevv/nim-memory. I'm
very interested to know what is plain wrong, what I missed, what could be better, or
what's great. Let me know on #nim or PR you changes at the source repo.


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
track of memory, typically leading to safer code (no use-after-free) and less
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

- Garbage collectors do not always play nice with threads, making it impossible
  or hard to share managed data between different threads.


== Introducing: ARC

With Nim version 1.2, a new model for memory management was introduced, called
_ARC_. With ARC, the compiler got much smarter about managing memory -  so
smart even, that garbage collection is no longer needed.

Instead of periodically interrupting the program and scan for unreferenced
memory, ARC builds on a number of other concepts: reference counting and
destructors.

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

A _destructor_ is a proc that gets called by Nim when the reference counter of
a ref drops to zero. Every type has its own destructor, the compiler will
generate default destructors for you that do the right thing if you do not
define one.

Destructors are implemented by a proc called `=destroy` and look like this:

----
proc `=destroy`(x: var T)
----

While the default destructors generated by the compiler will take care of
deallocating memory, custom destructors can be used for freeing or closing
other kinds of resources like file descriptors, sockets, or handles provided by
external libraries.


== Move semantics

The above two concepts - reference counting and destructors - are basically all
that is needed for managing memory: keep track of how many pointers reference a
block, and free the block when there are no more references.

While this sounds pretty simple and straightforward, the compiler also does a
number of smart things to also make it efficient, and to make sure it never
does more work then strictly needed.

This is where the _move semantics_ come in. Move semantics allow your code,
under certain conditions, to turn expensive memory copies into cheap _moves_.


=== Last use

TODO

=== Return value optimzation

TODO

=== Sinks

TODO

=== Lents

TODO

