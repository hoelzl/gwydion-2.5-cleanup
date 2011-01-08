module: errors
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

// ### The names for errors and error reporting functions are poorly
// chosen: <compiler-condition> should be the class for conditions
// signalled when problems in the compiler are detected;
// <program-conditions> should be the class for problems found in the
// user's program.  Unfortunately this would require rather large
// changes throughout the compiler, so I'll name compiler-internal
// conditions <internal-condition> for now.

// Error message output:

// *current-context* and *print-context* -- internal.
//
// These variables are used to maintain a notion of the current error context.
// When we print an error for the first time in some new context, we print
// out the context first.
// 
define variable *current-context* = #f;
define variable *print-context* :: <boolean> = #f;

// note-context -- exported.
//
// Set the current error context.  The next time an error is printed, call
// print-message on the context first.
// 
define function note-context (context :: <object>) => ();
  *current-context* := context;
  *print-context* := #t;
end function note-context;

// end-of-context -- exported.
//
// Note that we have finished the current error context, so don't print
// anything at the next error.
// 
define function end-of-context () => ();
  *current-context* := #f;
  *print-context* := #f;
end function end-of-context;


// <compiler-condition> -- exported.
//
// Superclass of all compiler conditions.  A compiler condition is some message
// to the user of the compiler about something about their program.
// 
define abstract class <compiler-condition> (<format-string-condition>)
  //
  // The source location this condition happened at.
  constant slot condition-at :: <source-location>,
    required-init-keyword: at:;
end class <compiler-condition>;

define sealed domain make (singleton(<compiler-condition>));
define sealed domain initialize (<compiler-condition>);

// report-condition{<compiler-condition>} -- method on imported GF.
//
// Print out the source location and the message.
// 
define method print-message
    (condition :: <compiler-condition>, stream :: <stream>)
    => ();
  pprint-logical-block
    (stream,
     body: method (stream :: <stream>)
	     describe-source-location(condition.condition-at, stream);
	     apply(format, stream, condition.condition-format-string,
		   condition.condition-format-arguments);
	   end method);
end method print-message;

// default-handler{<compiler-condition>} -- method on imported GF.
//
// By default just report the condition.  But first, make sure we are starting
// a new line and print the context if we haven't already.
// 
define method default-handler (condition :: <compiler-condition>) => ();
  fresh-line(*error-output*);
  if (*print-context*)
    format(*error-output*, "In %s:\n", *current-context*);
    *print-context* := #f;
  end if;
  format(*error-output*, "%s\n", condition);
end method default-handler;


// <compiler-error> -- exported.
//
// Things that are real problems with the program being compiled.  If any of
// these are signaled, then consider the program broken and make sure the
// exit status is non-zero when we finally exit.
// 
define class <compiler-error> (<compiler-condition>)
end class <compiler-error>;

define sealed domain make (singleton(<compiler-error>));

// *errors* -- exported.
//
// The number of <compiler-error>s that have been signaled.
// 
define variable *errors* :: <integer> = 0;

// *break-on-compiler-errors* -- exported.
//
// When set to #t, invoke the debugger whenever we hit a compiler error.
// This is only necessary because some compiler errors don't contain enough
// information to figure out what is wrong, so sometimes you have to tell
// the compiler to dump you into the debugger so that you can poke around
// yourself.
// 
define variable *break-on-compiler-errors* :: <boolean> = #f;

// default-handler{<compiler-error>} -- method on imported GF.
//
// Dink *errors* and report the error.  And break if *break-on-compiler-errors*
// is true.
// 
define method default-handler
    (error :: <compiler-error>, #next next-method) => ();
  *errors* := *errors* + 1;
  next-method();
  if (*break-on-compiler-errors*)
    break("hit a compiler error.");
  end if;
end method default-handler;


// <compiler-warning> -- exported.
//
// Things that are probably wrong with the program.  Signaling these does not
// cause the compile to fail, but they probably should be fixed anyway.
//
define class <compiler-warning> (<compiler-condition>)
end class <compiler-warning>;

define sealed domain make (singleton(<compiler-warning>));

// *warnings* -- exported.
//
// The number of <compiler-warning>s signaled so far.
// 
define variable *warnings* :: <integer> = 0;

// default-handler{<compiler-warning>} -- method on imported GF.
//
// Dink *warnings* and report the warning.
// 
define method default-handler
    (warning :: <compiler-warning>, #next next-method) => ();
  *warnings* := *warnings* + 1;
  next-method();
end method default-handler;



// <fatal-error-recovery-restart> -- exported.
//
// Restart used for recovering from fatal compiler errors.  After a fatal
// compiler error is signaled, one of these restarts is signaled.  The current
// handler is responsible for resuming compilation.
// 
define class <fatal-error-recovery-restart> (<restart>)
end class <fatal-error-recovery-restart>;

define sealed domain make (singleton(<fatal-error-recovery-restart>));
define sealed domain initialize (<fatal-error-recovery-restart>);



// compiler-warning-location -- exported
//
// Signals a compiler warning with an explicit source location.
//
define function compiler-warning-location
    (loc :: type-union(<source-location-mixin>, <source-location>),
     format-string :: <byte-string>, #rest format-arguments)
    => ();
  signal(make(<compiler-warning>,
	      at: select (loc by instance?)
		    <source-location> => loc;
		    <source-location-mixin> => loc.source-location;
		  end select,
	      format-string: stringify("Warning: ", format-string),
	      format-arguments: format-arguments));
end function compiler-warning-location;

// compiler-error-location -- exported.
//
// Signals a compiler error with an explicit source location.
//
define function compiler-error-location
    (loc :: type-union(<source-location-mixin>, <source-location>),
     format-string :: <byte-string>, #rest format-arguments)
    => ();
  signal(make(<compiler-error>,
	      at: select (loc by instance?)
		    <source-location> => loc;
		    <source-location-mixin> => loc.source-location;
		  end select,
	      format-string: stringify("Error: ", format-string),
	      format-arguments: format-arguments));
end function compiler-error-location;

// compiler-fatal-error-location -- exported.
//
// Signals a compiler error, followed by a fatal-error-recovery-restart.  This
// is used to signal compiler errors that can't be ignored by the compiler.
// 
define function compiler-fatal-error-location
    (loc :: type-union(<source-location-mixin>, <source-location>),
     format-string :: <byte-string>, #rest format-arguments)
    => res :: <never-returns>;
  apply(compiler-error-location, loc, format-string, format-arguments);
  signal(make(<fatal-error-recovery-restart>));
  error("Handler for <fatal-error-recovery-restart> returned but isn't "
	  "allowed to.");
end function compiler-fatal-error-location;

// compiler-{warning,error,fatal-error} -- external.
//
// Call compiler-{warning,error}-location with any location we can extract
// from the args.
// 
define function compiler-warning (string, #rest args) => ();
  apply(compiler-warning-location, find-source-loc(args), string, args);
end function compiler-warning;
//
define function compiler-error (string, #rest args) => ();
  apply(compiler-error-location, find-source-loc(args), string, args);
end function compiler-error;
//
define function compiler-fatal-error (string, #rest args) => ();
  apply(compiler-fatal-error-location, find-source-loc(args), string, args);
end function compiler-fatal-error;

// find-source-loc -- internal.
//
// Look in the rest args, hoping to find an object with a source location.
//
define function find-source-loc (args :: <sequence>) 
    => res :: <source-location>;
  block (return)
    for (x in args)
      if (instance?(x, <source-location-mixin>))
	return(x.source-location);
      end;
    finally
      make(<unknown-source-location>);
    end for;
  end block;
end function find-source-loc;



// Extract-source:
//
// Utility used to extract a source location from some thing.
// For now, and maybe always, we just take the source from the token.
//

define /* exported */ generic extract-source (wot) => res :: <source-location>;

define method extract-source (wot) => res :: <unknown-source-location>;
  make(<unknown-source-location>);
end method;

define method extract-source (wot :: <source-location-mixin>)
 => res :: <source-location>;
  wot.source-location;
end method;



// Internal Conditions
// ===================

// The following conditions should be signalled by the compiler if it
// detects an internal problem.
// ### TODO:
// * Clarify when internal warnings and errors are appropriated.
// * Define a restart protocol for internal warnings and errors.

// <internal-condition> -- exported
// 
define class <internal-condition> (<format-string-condition>)
end class <internal-condition>;

// report-condition{<compiler-condition>} -- method on imported GF.
//
// Print out the conditions's message.
// 
define method report-condition
    (condition :: <internal-condition>, stream :: <stream>)
 => ();
  pprint-logical-block
    (stream,
     body: method (stream :: <stream>)
	     apply(format, stream, 
                   condition.condition-format-string,
		   condition.condition-format-arguments);
	   end method);
end method report-condition;

// default-handler{<internal-condition>} -- method on imported GF.
//
// By default just report the condition starting on a new line.
// 
define method default-handler (condition :: <internal-condition>) => ();
  fresh-line(*error-output*);
  format(*error-output*, "%s\n", condition);
end method default-handler;

// <internal-warning> -- exported
//
define class <internal-warning> (<internal-condition>, <warning>)
end class <internal-warning>;

// internal-warning -- exported.
//
// Signals an internal warning.  This is used to signal errors in the
// compiler that are not immediately fatal.
// 
define function internal-warning
    (format-string :: <byte-string>, #rest format-arguments)
    => res :: <never-returns>;
  signal(make(<internal-warning>,
	      format-string: stringify("Compiler internal warning: ",
                                       format-string),
	      format-arguments: format-arguments));
end function internal-warning;

// <internal-error> -- exported
//
define class <internal-error> (<internal-condition>, <error>)
end class <internal-error>;

// internal-error -- exported.
//
// Signals an internal error, followed by a
// fatal-error-recovery-restart.  This is used to signal errors in the
// compiler that can't be ignored.
//
// ### Is using the fatal-error-recovery-restart the right thing to
// do?  Probably we should try to recover differently from internal
// compiler errors than from program errors. --tc
// 
define function internal-error
    (format-string :: <byte-string>, #rest format-arguments)
    => res :: <never-returns>;
  signal(make(<internal-error>,
	      format-string: stringify("Compiler internal error: ",
                                       format-string),
	      format-arguments: format-arguments));
  signal(make(<fatal-error-recovery-restart>));
  error("Handler for <fatal-error-recovery-restart> returned but isn't "
	  "allowed to.");
end function internal-error;
