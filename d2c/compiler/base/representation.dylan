module: representation
copyright: see below

//======================================================================
//
// Copyright (c) 1995 - 1997  Carnegie Mellon University
// Copyright (c) 1998 - 2000  Gwydion Dylan Maintainers
// All rights reserved.
// 
// Use and copying of this software and preparation of derivative
// works based on this software are permitted, including commercial
// use, provided that the following conditions are observed:
// 
// 1. This copyright notice must be retained in full on any copies
//    and on appropriate parts of any derivative works.
// 2. Documentation (paper or online) accompanying any system that
//    incorporates this software, or any part of it, must acknowledge
//    the contribution of the Gwydion Project at Carnegie Mellon
//    University, and the Gwydion Dylan Maintainers.
// 
// This software is made available "as is".  Neither the authors nor
// Carnegie Mellon University make any warranty about the software,
// its performance, or its conformity to any specification.
// 
// Bug reports should be sent to <gd-bugs@gwydiondylan.org>; questions,
// comments and suggestions are welcome at <gd-hackers@gwydiondylan.org>.
// Also, see http://www.gwydiondylan.org/ for updates and documentation. 
//
//======================================================================

define abstract open class <representation> (<object>)
end class <representation>;

define abstract open class <general-representation> (<representation>)
end class <general-representation>;

define abstract open class <heap-representation> (<representation>)
end class <heap-representation>;

define abstract open class <data-word-representation> (<representation>)
end class <data-word-representation>;

define abstract open class <immediate-representation> (<representation>)
end class <immediate-representation>;


define open generic pick-representation
    (type :: <ctype>, optimize-for :: one-of(#"speed", #"space"))
    => res :: <representation>;

define open generic representation-alignment (rep :: <representation>)
    => alignment :: <integer>;

define open generic representation-size (rep :: <representation>)
    => size :: <integer>;

define open generic representation-has-bottom-value? (rep :: <representation>)
    => res :: <boolean>;

define open generic use-data-word-representation
    (class :: <cclass>, data-word-type :: <ctype>) => ();

define open generic use-general-representation
    (class :: <cclass>) => ();

define open generic is-heap-representation?
    (rep :: <representation>) => (res :: <boolean>);

define open generic is-general-representation?
    (rep :: <representation>) => (res :: <boolean>);
