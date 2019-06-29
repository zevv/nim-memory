
= Nim memory
:toc:

todo: better title!

This is a document in progress, any comments are much appreciated. The source
can be found in github at https://github.com/zevv/nim-memory

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
end. This is called "last-in-first-out" (LIFO).


==== Stack theory

A good analogy for a stack is a stack of plates in a restaurant kitchen: new
plates are taken out of the dishwasher and added on top; when plates are
needed, they are also taken from the top. Plates are never inserted halfway or
on the bottom, and plates are never taken from the middle or bottom of the
stack.

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
  :    free      : v on the bottom

The administration for a stack is pretty simple: the program maintains needs to
keep track of single address which points to the current stack bottom. When
data is added to the stack, it is copied in place and the stack pointer is
decreased. When data is removed from the stack, it is copied out and the stack
pointer is again increased.

==== Stacks in practice

In Nim, C and most other compiled languages, the stack is used for two
different purposes: 

- first it is used as a place to store temporary local variables. These
  variables only exist in a function as long as the function is active (i.e. it
  has not returned).

- the compiler also uses the stack for a different kind of bookkeeping: every
  time a function is called, the address of the next instruction after the
  `call` instruction is placed on the stack - this is the _return address_.
  When the function returns, it finds that address on the stack, and jumps to
  it.

During program execution, this is what the stack will typically look like:

  +----------------+ <-- stack top
  | return address |
  | variable       | <-- stack frame #1
  | variable       |
  | ...            |
  +----------------+
  | return address |
  | variable       | <-- stack frame #2
  | ...            |
  +----------------+ <-- stack pointer
  |     free       |
  :                :

Using the stack for both data and return addresses is a pretty neat trick and
has the nice side effect of offering automatic storage allocation and cleanup
for data in a program.

Stacks also work nicely with threads: each thread simply has its own stack,
storing its own local variables and holding is own stack frames.

Now you know where Nim gets the information from when it generates a _stack
trace_ when it hits a run time error or exception: It will find the address of
the innermost active function on the stack, and print its name. Then it goes
looking further up the stack for the next level active function, all the way to
the top. 


=== Heaps

Next to the stack, the heap is the other place to store data in a computer
program. While the stack is typically used to hold local variables, the heap
can be used for more dynamic storage.

==== Heap theory

A heap is a region of memory which is a bit like a warehouse. The memory region
is called the _arena_:

  :              : ^ heap can grow at the top
  |              | |
  |              |
  |    free!     | <--- The heap arena
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

  :              :
  |    free      |
  |              |
  +--------------+
  |  allocated   | <--- allocation address
  +--------------+ 

The above process can be repeated, allocating other blocks on the heap, some of 
different sizes:
  
  :              :
  |    free      |
  +--------------+
  |              |
  | allocated #3 |
  |              |
  +--------------+
  | allocated #2 |
  +--------------+
  | allocated #1 |
  +--------------+ 

When the data block is no longer used, the program will tell the memory
allocator the address of the block. The allocator looks up the address in the
ledger, and removes the entry. This block is now free for future use. This
is what the above picture looks like when block #2 is released:

  :              :
  |    free      |
  +--------------+
  |              |
  | allocated #3 |
  |              |
  +--------------+
  |    free      | <-- There's a hole in the heap!
  +--------------+
  | allocated #1 |
  +--------------+ 

As you can see, the freeing of block #2 now leaves a hole in the heap, which
might lead to problems in the future. Consider the next allocation request:

- If the size of the next allocation is smaller then the size of the hole, the
  allocator might reuse the free space in the hole; but since the new request
  is smaller, a new smaller hole will be left after the new block

- If the size of the next allocation is bigger then the size of the hole, the
  allocator has to find a bigger free spot somewhere, leaving the hole open.

The only way to effectively reuse the hole is if the next allocation is of the
exact same size of the hole.

Heavy use of a heap with a lot of different sized objects might lead to a
phenomenom called _fragmentation_. This means that the allocator is not able to
effectively use 100% of the arena size to fulfil allocation requests,
effectively wasting a part of the available memory.


==== The heap in practice

In Nim, the `new()` proc is typically used allocate memory on the heap for a
new object:

----
type Thing = object
  a: int

var t = new Thing
----

The above snippet will allocate memory on the heap to store an object of type
`Thing` The _address_ of the newly allocated memory block is returned by `new`,
which is now of type `ref Thing`.

A `ref T` is a special kind of pointer, and Nim can do most of the magic for you
to make it easier to work with it. You can use a `ref object` just as if it was
a normal object on the stack, and Nim will make sure the right thing happens.


todo: garbage collector



== Memory organization in Nim

As long as you stick to the _safe_ parts of the language, Nim will take care of
managing memory allocations for you. It will make sure your data is stored at
the appropriate place, and freed when you no longer need it. However, if the
need arises, Nim offers you full control as well, allowing you to choose
exactly how and where to store your data.

Nim offers some handy functions to allow you to inspect how your data is
organized in memory:

`addr(x)`:: This proc returns the address of variable `x`. For a variable of
            type `T`, its address will have type `ptr T`

`unsafeAddr(x)`:: This proc is basically the same as `addr()`, but it can be
                  used even if Nim thinks it would not be safe to get the address
		  of an object - more on this later.

`sizeof(x)`:: Returns the size of variable `x` in bytes


The result of `addr(x)` and `unsafeAddr(x)` on an object of type `T` has a
result of type `ptr T`. Nim does not know how to print this by default, so we
will make use of `repr()` to nicely format a the type for us:

----
var a: int
echo a.addr.repr
# ref 0x56274ece0c60 --> 0
----


=== The stack: local variables

Local variables (also called _automatic_ variables) are the default method by
which Nim stores your variables and data.

Nim will reserve space for your variable on the stack, and it will stay there
as long as it is in scope. In practice, this means that the variable will exist
as long as the function in which it is declared does not return. As soon as the
function returns the stack _unwinds_ and the variables are gone.


==== Primitive types

A _primitive_ or _scalar_ type is a "single" value like an `int`, a `bool` or a
`float`.  Scalars are usually kept on the stack, unless they are part of a
container type like an object.

Let's see how Nim manages memory for primitive types for us. The snippet below
first creates a variable `a` of type `int` and prints this variable and its
size.  Then it will create a second variable `b` of type `ptr int` which is
called a _pointer_, and now holds the _address_ of variable `a`.

----
var a = 9
echo a.repr
echo sizeof(a)

var b = a.addr
echo b.repr
echo sizeof(b)
----

On my machine I might get the following output:

  9  <1>
  8  <2>
  ref 0x300000 --> 9 <3>
  8  <4>

<1> No surprise here: this is the value of variable `a`

<2> This is the size of the variable, in bytes. 8 bytes makes 64 bits, which
    happens to be the default size for `int` types in Nim. So far so good.

<3> This line shows a representation of variable `b`. `b` holds the address
    of variable `a`, which happens to live at address `0x300000`. In Nim an
    address is known as a _ref_ or a _pointer_.

<4> `b` itself is also a variable, which is not of the type `ptr int`. On
    my machine memory addresses also have a size of 64 bit, which equals 8
    bytes.


The above can be represented by the following diagram:

            +---------------------------------------+
 0x??????:  | 00 | 00 | 00 | 00 | 30 | 00 | 00 | 00 | b: ptr int = 0x300000
            +---------------------------------------+
                                |
                                |
                                v
            +---------------------------------------+
 0x300000:  | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 09 | a: int = 9
            +---------------------------------------+


==== Arrays

todo


==== Compound types

Let's put a more complicated object on the stack and see what happens:

----
type Thing = object <1>
  a: uint32
  b: uint8
  c: uint16

var t: Thing <2>

echo "size t   ", t.sizeof  <3>
echo "size t.a ", t.a.sizeof
echo "size t.b ", t.b.sizeof
echo "size t.b ", t.c.sizeof

echo "addr t   ", t.addr.repr  <4>
echo "addr t.a ", t.a.addr.repr
echo "addr t.b ", t.b.addr.repr
echo "addr t.c ", t.c.addr.repr
----

<1> The definition of our object type `Thing`, which holds integers of various
    sizes

<2> Create a variable `t` of type `Thing`

<3> Print the size of `t` and all its fields

<4> Print the address of `t` and all its fields

In Nim, an object is just a way of grouping variables into a handy container,
making sure they are placed next to each other in memory the same way as C
would do.

Here is the output on my machine:

----
size t.a 4  <1>
size t.b 1
size t.b 2
size t   8  <2>
addr t   ref 0x300000 --> [a = 0, b = 0, c = 0]  <3>
addr t.a ref 0x300000 --> 0  <4>
addr t.b ref 0x300004 --> 0
addr t.c ref 0x300006 --> 0  <5>
----

Lets go through the output:

<1> First we get the size of fields of the object. `a` was declared as an `uint32`, which
    is 4 bytes big, `b` is an `uint8` which is 1 byte, and `c` is an `uint16` which is 2 bytes
    big. check!

<2> Here is a bit of a surprise: we print the size of the container object `t`, which seems
    to be 8 bytes big. But that does not add up, as the contents of the object is
    only 4+1+2 = 7 bytes! More on this below.

<3> Let's get the address of the object `t`: on my machine it was placed on
    address `0x300000` on the stack.

<4> Here we can see that the field `t.a` lies at exactly the same place in memory as the object
    itself: `0x300000`. The address of `t.b` is `0x300004`, which is 4
    bytes after `t.a`. That makes sense, since `t.a` is four bytes big.

<5> The address of `t.c` is `0x300006`, which is 2 (!) bytes after `t.b`, but `t.b` is only
    one byte big?

So, let's draw a little picture of what we have learned from the above:

----
              00   01   02   03   04   05   06   07
            +-------------------+----+----+---------+
 0x300000:  | a                 | b  | ?? | c       |    <- object t
            +-------------------+----+----+---------+
            ^                   ^         ^ 
            |                   |         |
         address of           addr       addr
         t and t.a           of t.b     of t.c
----

So this is what our `Thing` object looks like in memory.  So what is up with
the hole marked `??` at offset 5, and why is the total size not 7 but 8 bytes?

This is caused by something the compiler does which is called _alignment_, to
make it easier for the CPU to access the data in memory. By making sure objects
are nicely aligned in memory at a multiple of their size (or a multiple of the
architecture's word size), the CPU can access the memory more efficiently. This
usually results in faster code, at the price of wasting some memory.

(You can hint the Nim compiler not to do alignment but to place the fields of
an object back-to-back in memory using the `{.packed.}` pragma - refer to the
Nim language manual for details)


=== The heap: refs

todo


== Complex data types

The above sections described how Nim manages relativily simple static objects
in memory. This section will go into the implementation of more complex and
dynamic data types which are part of the Nim language: strings and seqs.

=== Strings and seqs

In Nim, the `string` and `seq` data types are closely related. These are
basically a long row of objects of the same type (chars for a strings, any
other type for seqs). What is different for these types is that they can
dynamically grow or shrink in memory.

==== Seq internals

Lets create a `seq` and do some experiments with it:

----
var a = @[ 30, 40, 50 ]
----

Let's ask Nim what the type of variable `a` is:

----
import typetraits
var a = @[ 30, 40, 50 ]
echo a.type.name   # -> seq[int]
----

We see the type is `seq[int]`, which is what we expected.

Now, lets add some code to see how Nim stores the data:

----
var a = @[ 0x30, 0x40, 0x50 ]
echo a.repr
echo a.len
echo a[0].addr.repr
echo a[1].addr.repr
----

And here is the output on my machine:

----
ref 0x300000 --> 0x900048@[0x30, 0x40, 0x50]  <1>
3 <2>
ref 0x900058 --> 0x30  <3>
ref 0x900060 --> 0x40  <4>
----

What can we deduce from this?

<1> The variable `a` itself is placed on the stack, which happens to be at
    address `0x300000` on my machine. A is some kind of pointer that points to
    address `0x900048` which is on the heap! And this is where the actual seq
    lives.

<2> This seq contains 3 elements, just as it should be.

<3> `a[0]` is the first element of the seq. Its value is `0x30`, and i is stored
    at address `0x900058`, which is right after the seq itself

<4> The second item in the seq is `a[1]`, which is placed at address `0x900060`.
    This makes perfect sense, as the size of an `int` in nim is 8 bytes, and all
    ints in the seq are placed back-to-back in memory.

Let's make a little drawing again. We know `a` is a pointer living on the
stack, which refers to something on the heap with a size of 16 bytes, followed
by the elements of our seq:

              stack 
            +---------------------------------------+
 0x300000   | 00 | 00 | 00 | 00 | 90 | 00 | 00 | 48 | a: seq[int]
            +---------------------------------------+
                                |
              heap              v
            +---------------------------------------+
 0x900048   | ?? | ?? | ?? | ?? | ?? | ?? | ?? | ?? |
            +---------------------------------------+
 0x900050   | ?? | ?? | ?? | ?? | ?? | ?? | ?? | ?? |
            +---------------------------------------+
 0x900058   | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 30 | a[0] = 0x30
            +---------------------------------------+
 0x900060   | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 40 | a[1] = 0x40
            +---------------------------------------+
 0x900068   | 00 | 00 | 00 | 00 | 00 | 00 | 00 | 50 | a[2] = 0x50
            +---------------------------------------+

This almost explains all of the seq, except for the 16 unknown bytes at the
start of the heap block. This area is where Nim stores its internal information
about the seq, of which the most important is the seqs length.


==== Growing a seq

The little snippet below creates a seq, and fills it with the numbers 0..7.
Each iteration it will show what happens:

----
var a: seq[int]
echo a.repr

for i in 0..7:
  a.add i
  echo a.addr.repr
----

Here is the output, see if you can spot the interesting bits:

----
ref 0x300000 --> 0x900048@[0]  <1>
ref 0x300000 --> 0x900078@[0, 1] <2>
ref 0x300000 --> 0x9000c8@[0, 1, 2] <3>
ref 0x300000 --> 0x9000c8@[0, 1, 2, 3]
ref 0x300000 --> 0x9001b0@[0, 1, 2, 3, 4] <4>
ref 0x300000 --> 0x9001b0@[0, 1, 2, 3, 4, 5]
ref 0x300000 --> 0x9001b0@[0, 1, 2, 3, 4, 5, 6]
ref 0x300000 --> 0x9001b0@[0, 1, 2, 3, 4, 5, 6, 7]
----

<1> Here Nim shows us the seq: the ref lives at address `0x300000`,
    which is on the stack. The actual seq data is placed on the heap
    at address `0x900048`

<2> Something happened here: the ref to our seq still lives a the same place
    on the stack, but it now points to a different address! The reason for this
    is that the inital memory allocation for the seq data on the heap was not
    large enough to fit the new element, so Nim had to find a larger chunk of
    memory to hold the data. It is likely that the allocator already reserved
    the area directly behind the seq to something else, so it was not possible
    to grow this area. Instead, a new allocation somewhere else on the heap was
    made, the old data of the seq was copied from the old location to the new
    location, and the new element was added.

<3> The same thing happens here when yet another element is added. Note that
    for the next `add(3)`, no new allocation was done! The reason for this is
    that Nim anticipates more data to be added to the seq, and grows its memory
    area in powers of two: the block is now large enough to hold 4 elements

<4> And here the same happens once more: The block is not large enough to
    fit the 5th item, so the whole seq is moved to another place, and the allocation
    is scaled up to hold 8 elements.

=== Tables

todo




