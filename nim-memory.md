
= Nim memory
:toc:

todo: better title!


== Introduction

This is a small tutorial explaining how Nim stores data in memory (RAM). It
will explain the essentials which every Nim programmer should know, but it will
also dive deeper in the way Nim organizes its data structures like strings and
seqs.

For most practical purposes, Nim will take care of all memory management for
your program without bothering you with the details. As long as you stick to
the safe parts of the language, you will rarely have to work with memory
addresses, or make explicit memory allocations. This changes however when you
want your Nim code to interop with external C code or C libraries - in this
case you might need to know where and how your Nim objects are stored in memory
so you can pass this to C, or you will need to know how to access C-allocated
data to make it accessible by Nim.

The first parts of this document will be familiar to readers with a C or C++
background, as a lot of it is not unique to the Nim language. In contrast, some
things might be new to programmers coming from dynamic languages like Python or
Javascript, where memory handling is more abstracted away.

NOTE: Most - if not all - of this document applies to the C and C++ code generator,
since the Javascript backend does not use raw memory but relies on Javascript
objects instead.


== Computer memory basics

This section gives a brief and abstract introduction (warning: gross
simplifications ahead!) about computer memory, and what it looks like from the
point of view of a CPU and a computer program.

A computer's main memory (RAM) consists of a lot of memory locations, each of
which has an unique address. Depending on the CPU architecture the size of each
memory location (the "word size") typically varies between one byte (8 bit) to
eight bytes (64 bit), while the CPU is usually also able to access large words
as smaller chunks. Some architectures can read and write memory from arbitrary
addresses, while others can only access memory at addresses which are a
multiple of the word size.

The CPU accesses memory using specific instructions that allow it to read or
write data of a given word size from or to a given address. For example, it
might store the value 0x12345 as a 32 bit number at address 0x100000. The low
level assembly instruction for doing this might look something like this:

   mov [0x100000], 0x12345

This is what the memory on address 0x100000 will look like after the above
instruction completes, with each column representing a byte:

               0    1    2    3   4 
            +----+----+----+----+----
  0x100000  | 00 | 01 | 23 | 45 | ..
            +----+----+----+----+----

todo: endianess

== Two ways to organize memory

Traditionally, C programs use two common methods used for organizing objects in
computer memory: the _stack_ and the _heap_. Both methods serve different
purposes and have very different characteristics.


=== Stacks

A stack is a region of memory where data is always added and removed from one
end. This is called "last-in-first-out" (LIFO). Compare this with a stack of
plates in a restaurant: new plates are taken out of the dishwasher and added on
top; when plates are needed, they are also taken from the top. Plates are never
inserted halfway or on the bottom, and plates are never taken from the middle
or bottom of the stack.

For historical reasons, computer stacks usually work top down: new data is
added to and removed from the bottom of the stack, but this does not change the
mechanism itself.

  +--------------+ <-- stack top
  |              |
  |   in use     |
  |              |
  |              |
  +--------------+ <-- stack pointer
  |              |
  |              | | new data added
  :   free       : v on the bottom

The administration for a stack is pretty simple: the program maintains needs to
keep track of single address which points to the current stack bottom. When
data is added to the stack, it is copied in place and the stack pointer is
decreased. When data is removed from the stack, it is copied out and the stack
pointer is again increased.

todo: stacks and threading, call stack, stack frames


=== Heaps

A heap is a region of memory which is a bit like a warehouse. The memory region
is called the _arena_:

  +--------------+
  |              |
  |              |
  |    free!     |
  |              |
  |              |
  +--------------+

When a program wants to store data, it will first calculate how much storage it
will need. It will then go to the warehouse clerk (the memory allocator) and
request a place to store the data. The clerk has a ledger where it keeps track
of all allocations in the warehouse, and it will find a free spot that is large
enough to fit the data. It will then make an entry in the ledger that the area
at that address and size is now taken, and it returns the address to the
program. The program can now store and retrieve its data from this area in
memory at will.

  +--------------+
  |              |
  |    free      |
  |              |
  +--------------+
  |   allocated  | <--- allocation address
  +--------------+ 

When the data block is no longer used, the program will tell the memory
allocator the address of the block. The allocator looks up the address in the
ledger, and removes the entry. This block is now free for future use.

todo: fragmentation, realloc


== Memory organization in Nim

As long as you stick to the _safe_ parts of the Nim language, it will take care
of managing memory allocations for you. It will make sure your data is stored
at the appropriate place, and freed when you no longer need it. However, if the
need arises, Nim offers you full control as well, allowing you to choose
exactly how and where to store your data.

todo: garbage collector, newruntime

Nim offers some handy functions to allow you to inspect how your data is
organized in memory:

`addr(x)`:: This proc returns the address of variable `x`. For a variable of type `T`,
            its address will have type `ptr T`

`sizeof(x)`:: Returns the size of variable `x` in bytes

`repr(x)`:: Pretty format expression `x`


=== Local variables

Local variables (also called _automatic_ variables) are the default method by
which Nim stores your variables and data.

Nim will reserve space for the variable on the stack, and it will stay there as
long as it is in scope. In practice, this means that the variable will exist as
long as the function in which it is declared does not return. As soon as the
function returns the stack _unwinds_ and the variables are gone.

The above is best explained with a simple example: this snippet first creates a
variable `a` of type `int` and prints this variable and its size.  Then it will
create a second variable `b` of type `ptr int` which is called a _pointer_, and
now holds the _address_ of variable `a`.

----
var a = 9
echo a.repr
echo sizeof(a)

var b = a.addr
echo b.repr
echo sizeof(b)
----

On my machine I might get the following output:

  9                       <1>
  8                       <2>
  ref 0x30000000 --> 9    <3>
  8                       <4>

<1> No surprise here: this is the value of variable `a`

<2> This is the size of the variable, in bytes. 8 bytes makes 64 bits, which
    happens to be the default size for `int` types in Nim. So far so good.

<3> This line shows a representation of variable `b`. `b` holds the address
    of variable `a`, which happens to live at address `0x30000000`. In Nim an
    address is known as a _ref_ or a _pointer_.

<4> `b` itself is also a variable, which is not of the type `ptr int`. On
    my machine memory addresses also have a size of 64 bit, which equals 8
    bytes.


The above can be represented by the following diagram:

              +---------------------------------------+
 0x????????:  | 00 | 00 | 00 | 00 | 30 | 00 | 00 | 00 | b: ptr int = 0x30000000
              +---------------------------------------+
                                  |
                                  |
                                  v
              +---------------------------------------+
 0x30000000:  | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 09 | a: int = 9
              +---------------------------------------+





=== Refs

=== Strings and seqs

=== Objects

=== Sum types





