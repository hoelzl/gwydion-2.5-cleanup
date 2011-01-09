module: main
copyright: see below

//======================================================================
//
// Copyright (c) 1995, 1996, 1997  Carnegie Mellon University
// Copyright (c) 1998 - 2011  Gwydion Dylan Maintainers
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


//----------------------------------------------------------------------
// Built-in help.
//----------------------------------------------------------------------

define method show-copyright(stream :: <stream>) => ()
  format(stream, "d2c (Gwydion Dylan) %s\n", $version);
  format(stream, "Compiles Dylan source into C, then compiles that.\n");
  format(stream, "Copyright 1994-1997 Carnegie Mellon University\n");
  format(stream, "Copyright 1998-2006 Gwydion Dylan Maintainers\n");
end method show-copyright;

define method show-usage(stream :: <stream>) => ()
  format(stream,
"Usage: d2c [options] -Llibdir... lidfile\n");
end method show-usage;

define method show-usage-and-exit() => ()
  show-usage(*standard-error*);
  exit(exit-code: 1);
end method show-usage-and-exit;

define method show-help(stream :: <stream>) => ()
  show-copyright(stream);
  format(stream, "\n");
  show-usage(stream);
  format(stream,
"       -i, --interactive  Enter interactive command mode.\n"
"       -L, --libdir:      Extra directories to search for libraries.\n"
"       -D, --define:      Define conditional compilation features.\n"
"       -U, --undefine:    Undefine conditional compilation features.\n"
"       -M, --log-deps:    Log dependencies to a file.\n"
"       --dump-du:         Create human-readable lib.du.txt file.\n"
"       -T, --target:      Target platform name.\n"
"       -p, --platforms:   File containing platform descriptions.\n"
"       --no-binaries:     Do not compile generated C files.\n"
"       --no-makefile:     Do not create makefile for generated C files. Implies --no-binaries.\n"
"       -g, --debug:       Generate debugging code.\n"
"       --profile:         Generate profiling code.\n"
"       -s, --static:      Force static linking.\n"
"       -j, --thread-count Max threads to use (default 1)\n"
"       -d, --break:       Debug d2c by breaking on errors.\n"
"       -o, --optimizer-option:\n"
"                          Turn on an optimizer option. Prefix option with\n"
"                          'no-' to turn it off.\n"
"       --debug-optimizer <verbosity>:\n"
"                          Display detailed optimizer information.\n"
"                          Integer argument specifies verbosity (0-5)\n"
"       --optimizer-sanity-check:\n"
"                          Sanity check optimizer\n"
"       -F, --cc-override-command:\n"
"                          Alternate method of invoking the C compiler.\n"
"                          Used on files specified with -f.\n"
"       -f, --cc-override-file:\n"
"                          Files which need special C compiler invocation.\n"
"       --help:            Show this help text.\n"
"       --version          Show version number.\n"
	   );
end method show-help;

define method show-compiler-info(stream :: <stream>) => ()
  local method p (#rest args)
	  apply(format, stream, args);
	end;

  // This output gets read by ./configure.
  // All output must be of the form "KEY=VALUE". All keys must begin with
  // "_DCI_" (for "Dylan compiler info") and either "DYLAN" (which designates
  // a general purpose value) or "D2C" (which should be used for anything
  // which is necessarily specific to d2c).

  // This value indicates how much of LID we implement correctly.
  //   0: We only support CMU-style LID files.
  //   1: We support everything from 0 plus the 'File:' keyword.
  //   2: 1 but with unit-prefix being ignored
  p("_DCI_DYLAN_LID_FORMAT_VERSION=2\n");

  // Increment CURRENT_BOOTSTRAP_COUNTER in configure.in to force an
  // automatic bootstrap.
  p("_DCI_D2C_BOOTSTRAP_COUNTER=%d\n", $bootstrap-counter);

  // The directory (relative to --prefix) where ./configure can find our
  // runtime libraries. This is used when bootstrapping.
  p("_DCI_D2C_RUNTIME_SUBDIR=%s/%s\n", $version, $default-target-name);

  // The absolute path to where d2c searches for user-installed libraries.
  // This is used by the Makefile generated by make-dylan-lib to install
  // site-local Dylan code in the right directoy.
  p("_DCI_D2C_DYLAN_USER_DIR=%s/lib/dylan/%s/%s/dylan-user\n",
    $dylan-user-dir, $version, $default-target-name);

  // The library search path in effect.
  p("_DCI_D2C_DYLANPATH=");
  for (dir in *Data-Unit-Search-Path*, first? = #t then #f)
    unless (first?) p("%c", $search-path-seperator) end;
    p("%s", dir);
  end for;
  p("\n");

  // Shared library support
  p("_DCI_D2C_SHARED_SUPPORT=%s\n",
    if (*current-target*.shared-library-filename-suffix
          & *current-target*.shared-object-filename-suffix
          & *current-target*.link-shared-library-command)
      "yes";
    else
      "no";
    end if);
end method;

define method show-dylan-user-location(stream :: <stream>) => ()
  format(stream, "%s/lib/dylan/%s/%s/dylan-user\n",
         $dylan-user-dir, $version, $default-target-name);
end method;


//----------------------------------------------------------------------
// <feature-option-parser> - handles -D, -U
//----------------------------------------------------------------------
// d2c has a delightfully non-standard '-D' flag with a corresponding '-U'
// flag which allows you to undefine things (well, sort of). We create a
// new option parser class to handle these using the option-parser-protocol
// module from the command-line-parser library.

define class <d2c-feature-option-parser> (<negative-option-parser>)
end class <d2c-feature-option-parser>;

define method reset-option-parser
    (parser :: <d2c-feature-option-parser>, #next next-method) => ()
  next-method();
  parser.option-value := make(<deque> /* of: <string> */);
end;

define method parse-option
    (parser :: <d2c-feature-option-parser>,
     arg-parser :: <argument-list-parser>)
 => ()
  let negative? = negative-option?(parser, get-argument-token(arg-parser));
  let value = get-argument-token(arg-parser).token-value;
  push-last(parser.option-value,
	    if (negative?)
	      concatenate("~", value)
	    else
	      value
	    end if);
end method parse-option;


// Option Parsers
// ==============
define function set-up-argument-list-parser (argp :: <argument-list-parser>) => ();
  add-option-parser-by-type(argp,
                           <simple-option-parser>,
                           long-options: #("interactive"),
                           short-options: #("i"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("help"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("version"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("compiler-info"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("dylan-user-location"));
  add-option-parser-by-type(argp,
			    <repeated-parameter-option-parser>,
			    long-options: #("libdir"),
			    short-options: #("L"));
  add-option-parser-by-type(argp,
			    <d2c-feature-option-parser>,
			    long-options: #("define"),
			    short-options: #("D"),
			    negative-long-options: #("undefine"),
			    negative-short-options: #("U"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("log-deps"),
			    short-options: #("M"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("dump-du"));
  add-option-parser-by-type(argp,
			    <parameter-option-parser>,
			    long-options: #("target"),
			    short-options: #("T"));
  add-option-parser-by-type(argp,
			    <parameter-option-parser>,
			    long-options: #("platforms"),
			    short-options: #("p"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("no-binaries"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("no-makefile"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("break"),
			    short-options: #("d"));
  add-option-parser-by-type(argp,
			    <parameter-option-parser>,
			    long-options: #("cc-override-command"),
			    short-options: #("F"));
  add-option-parser-by-type(argp,
			    <repeated-parameter-option-parser>,
			    long-options: #("cc-override-file"),
			    short-options: #("f"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("debug"),
			    short-options: #("g"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("profile"));
  add-option-parser-by-type(argp,
			    <parameter-option-parser>,
			    short-options: #("j"),
			    long-options: #("thread-count"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("testworks-spec"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("optimizer-sanity-check"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("optimizer-sanity-check"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("static"),
			    short-options: #("s"));
  add-option-parser-by-type(argp,
			    <parameter-option-parser>,
			    long-options: #("rpath"));
  add-option-parser-by-type(argp,
			    <parameter-option-parser>,
			    long-options: #("debug-optimizer",
					    "dump-transforms"));
  add-option-parser-by-type(argp,
			    <simple-option-parser>,
			    long-options: #("debug-compiler"));
  add-option-parser-by-type(argp,
			    <repeated-parameter-option-parser>,
			    long-options: #("optimizer-option"),
			    short-options: #("o"));
end function set-up-argument-list-parser;
