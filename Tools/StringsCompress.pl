#======================================================================================
#
# Project name	:	XTIDE Universal BIOS
#
# Authors       :   Greg Lindhorst
#                   gregli@hotmail.com
#
# Description	:	Script for compiling and compressing strings for
#                   use by DisplayFormatCompressed.asm.  See the header of that file
#                   for a description of the compression scheme.
#
# XTIDE Universal BIOS and Associated Tools 
# Copyright (C) 2009-2010 by Tomi Tilli, 2011-2012 by XTIDE Universal BIOS Team.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.		
# Visit http://www.gnu.org/licenses/old-licenses/gpl-2.0.html
#

#
# Usage         :   stdin:  Listing of strings.asm,
#                           assembled with MODULE_STRINGS_COMPRESSED_PRECOMPRESS.
#                           We used the listing so that the assembler can take care of
#                           resolving %define and EQU symbol definitions.
#
#                   stdout: StringsCompressed.asm,
#                           plug replacement for Strings.asm (included by Main.asm)
#
#                   Also see the XTIDE makefile for building StringsCompressed.asm
#

#----------------------------------------------------------------------
#
# Translated, Format, and "Normal" characters
#
# DisplayFormatCompressed can only deal with characters in one of the following categories:
#  1. Those in the Translate associative array
#  2. Those in the Format associative array
#  3. Characters between $normal_base and $normal_base+0x40
#     (typically covers upper and lower case alphabets)
#  4. Null characters (marking the end of strings)
#  5. The special string LF,CR
#
# If a character or format read at the input cannot be found in one of the above categories,
# it must be added here before this script will accept it (and DisplayFormatCompressed can
# display it).
#
# Tables for the above categories are expected in the input stream, before string to be
# compressed are provided.  Note that these tables are not present in DisplayFormatCompressed,
# and do not need to be updated there.  Needed information is put in the compression output
# that it reads.
#

#
# High order code bits, determining which type of character we have (translated or not) and
# if a space or null should come after this character.
#
$code_space = 0xc0;
$code_null = 0x80;
$code_normal = 0x40;
$code_translate = 0x00;

#
# Bit used if it is a translated byte
#
$code_translate_null = 0x00;
$code_translate_normal = 0x20;

print ";;;======================================================================\n";
print ";;;\n";
print ";;; This file is generated by StringsCompress.pl from source in Strings.asm\n";
print ";;; DO NOT EDIT DIRECTLY - See the makefile for how to rebuild this file.\n";
print ";;; This file only needs to be rebuilt if Strings.asm is changed.\n";
print ";;;\n";
print ";;;======================================================================\n\n";

print "%ifdef STRINGSCOMPRESSED_STRINGS\n\n";

#
# On a first pass, look for our table directives.  $translate{...}, $format{...}, etc.
# are expected in the input stream.
#
$processed = "    [StringsCompress Processed]";
while(<>)
{
	chop;
	$o = $_;

	#
	# Table entries for this script
	#
	if( /^\s*\d+\s*(\;\$translate\{\s*ord\(\s*'(.)'\s*\)\s*\}\s*=\s*([0-9]+).*$)/ )
	{
		$translate{ord($2)} = int($3);
		$o .= $processed;
	}
	elsif( /^\s*\d+\s*(\;\$translate\{\s*([0-9]+)\s*\}\s*=\s*([0-9]+).*$)/ )
	{
		$translate{int($2)} = int($3);
		$o .= $processed;
	}
	elsif( /^\s*\d+\s*(\;\$format_begin\s*=\s*([0-9]+).*$)/ )
	{
		$format_begin = int($2);
		$o .= $processed;
	}
	elsif( /^\s*\d+\s*(\;\$format\{\s*\"([^\"]+)\"\s*\}\s*=\s*([0-9]+).*$)/ )
    {
    	$format{$2} = int($3);
		$o .= $processed;
	}
	elsif( /^\s*\d+\s*(\;\$normal_base\s*=\s*0x([0-9a-fA-F]+).*$)/ )
	{
		$normal_base = hex($2);
		$o .= $processed;
	}
	elsif( /^\s*\d+\s*(\;\$normal_base\s*=\s*([0-9]+).*$)/ )
	{
		$normal_base = int($2);
		$o .= $processed;
	}

	push( @lines, $o );
}

#
# On the second pass, loop through lines of the listing, looking for 'db' lines
# (and dealing with continuations) and compressing each line as it is encountered.
#
for( $l = 0; $l < $#lines; $l++ )
{
	$_ = $lines[$l];

	#
	# The <number> indicates a line from an include file, do not include in the output
	#
	if( /^\s*\d+\s*\<\d\>/ )
	{
	}

	#
	# a 'db' line, with or without a label
	#
	elsif( /^\s*\d+\s[0-9A-F]+\s([0-9A-F]+)(-?)\s+([a-z0-9_]+:)?(\s+)(db\s+)(.*)/i )
	{
		$bytes = $1;
		$continuation = $2;
		$label = $3;
		$spacing = $4;
		$db = $5;
		$string = $6;

		print $label.$spacing."; ".$db.$string."\n";

		if( $continuation eq "-" )
		{
			do
			{
				$_ = $lines[++$l];
				/^\s*\d+\s[0-9A-F]+\s([0-9A-F]+)(\-?)/i || die "parse error on continuation: '".$_."'";
				$bytes .= $1;
				$continuation = $2;
			}
			while( $continuation eq "-" );
		}

		&processString( $bytes, $label.$spacing, $db );
	}

	#
	# a ';%%;' prefix line, copy to output without the prefix
	#
	elsif( /^\s*\d+\s*;%%;\s*(.*)$/ )
	{
		print $1."\n";
	}

	#
	# everything else, copy to the output as is
	#
	elsif( /^\s*\d+\s*(.*)$/ )
	{
		print $1."\n";
	}
}

print ";;; end of input stream\n\n";

#--------------------------------------------------------------------------------
#
# Output constants and the TranslatesAndFormats table
#

print "%endif ; STRINGSCOMPRESSED_STRINGS\n\n";
print "%ifdef STRINGSCOMPRESSED_TABLES\n\n";

print "StringsCompressed_NormalBase     equ   ".$normal_base."\n\n";

print "StringsCompressed_FormatsBegin   equ   ".$format_begin."\n\n";

print "StringsCompressed_TranslatesAndFormats: \n";

foreach $f (keys(%translate))
{
	$translate_index[$translate{$f}] = $f;
	$used{$f} || die "translate $f unused\n";
	$translate{$f} <= 31 || die $translate{$f}.": translate codes must be below 32";
}

for( $g = 0; $translate_index[$g]; $g++ )
{
	print "        db     ".$translate_index[$g]."  ; ".$g."\n";
}

foreach $f (keys(%format))
{
	$n = $f;
	$n =~ s/\-/_/g;
	$format_index[$format{$f}] = "DisplayFormatCompressed_Format_".$n;
	$used{$f} || die "format $f unused\n";
	$format{$f} <= 31 || die $format{$f}.": format codes must be below 32";
}

for( $t = $format_begin; $format_index[$t]; $t++ )
{
	print "        db     (DisplayFormatCompressed_BaseFormatOffset - ".$format_index[$t].")    ; ".$t."\n";
}

print "\n";

#
# Ensure that branch targets are within reach
#
print "%ifndef CHECK_FOR_UNUSED_ENTRYPOINTS\n";
for( $t = $format_begin; $format_index[$t]; $t++ )
{
	print "%if DisplayFormatCompressed_BaseFormatOffset < $format_index[$t] || DisplayFormatCompressed_BaseFormatOffset - $format_index[$t] > 255\n";
	print "%error \"".$format_index[$t]." is out of range of DisplayFormatCompressed_BaseFormatOffset\"\n";
	print "%endif\n";
}
print "%endif\n";

#--------------------------------------------------------------------------------
#
# Output usage statistics
#

print "\n;; translated usage stats\n";
foreach $f (keys(%translate))
{
	print ";; ".$f.":".$used{$f}."\n";
	$translate_count++;
}
print ";; total translated: ".$translate_count."\n";

print "\n;; format usage stats\n";
$format_count = 0;
foreach $f (keys(%format))
{
	print ";; ".$f.":".$used{$f}."\n";
	$format_count++;
}
print ";; total format: ".$format_count."\n";

print "\n;; alphabet usage stats\n";

$used_count = 0;
for( $t = $normal_base; $t < $normal_base + 0x40; $t++ )
{
	print ";; ".$t.",".chr($t).":".$used{$t}."\n";
	if( $used{$t} )
	{
		$used_count++;
	}
}
print ";; alphabet used count: ".$used_count."\n";

print "%endif ; STRINGSCOMPRESSED_TABLES\n\n";

#--------------------------------------------------------------------------------
#
# processString does the real compression work...
#

sub processString
{
	$chars = $_[0];
	$label = $_[1];
	$db = $_[2];

	$label =~ s/[a-z0-9_:]/ /ig;      # replace with spaces for proper output spacing

	#
	# Copy numeric bytes out of hexadecimal pairs in the listing
	#
	$#v = 0;

	$orig = "";
	for( $g = 0; $g < length($chars); $g += 2 )
	{
		$i = $g/2;
		$v[$i] = hex(substr($chars,$g,2));
		$orig .= sprintf( ($v[$i] > 0x9f ? ", %03xh" : ",  %02xh"), $v[$i] );
	}
	$v[length($chars)/2] = 0xff;      # guard byte to avoid thinking going past the end of
	                                  # the string is a null

	$output = "";
	#
	# Loop through bytes...
	# looking ahead as needed for possible space and null optimizations, compiling formats
	#
	for( $g = 0; $g < $#v-1; $g++ )    # -1 for the guard byte
	{
		#
		# Special translation of LF,CR to a format
		#
		if( $v[$g] == 10 && $v[$g+1] == 13 )
		{
			$g++;
			$post = $code_translate;
			$code = $format{"nl"};
			$used{"nl"}++;
		}

		#
		# Format operators
		#
		elsif( $v[$g] == 0x25 )    # "%"
		{
			$fo = "";
			$g++;
			if( $v[$g] >= ord("0") && $v[$g] <= ord("9") )
			{
				$fo = $fo.chr($v[$g]);
				$g++;
			}
			if( $v[$g] == ord("-") )
			{
				$fo = $fo.chr($v[$g]);
				$g++;
			}
			$fo = $fo.chr($v[$g]);

			$format{$fo} || die "unknown format operator: '".$fo."'\n";

			$code = $format{$fo};
			$post = $code_translate;
			$used{$fo}++;
		}

		#
		# Translated characters
		#
		elsif( $v[$g] == 32 || $translate{$v[$g]} )
		{
			$post = $code_translate;
			$code = $translate{$v[$g]};
			$used{$v[$g]}++;
		}

		#
		# "normal" characters (alphabet, and ASCII characters around the alphabet)
		#
		elsif( $v[$g] >= $normal_base && $v[$g] < ($normal_base+0x40) )
		{
			$used{$v[$g]}++;

			$post = $code_normal;
			$code = $v[$g] - $normal_base;
		}

		#
		# Not found
		#
		else
		{
			die $v[$g].": no translation or format, and out of normal range - may need to be added\n";
		}

		if( $post == $code_translate )
		{
			#
			# NULL optimization (space optimization not possible on translate/format)
			#
			if( $v[$g+1] == 0 )
			{
				$g++;
				$post = $post | $code_translate_null;
			}
			else
			{
				$post = $post | $code_translate_normal;
			}
		}
		else # $post == $code_normal
		{
			#
			# Space optimization
			#
			if( $v[$g+1] == 0x20 && $v[$g+2] != 0 )
			{
				# can't take this optimization if the next byte is a null,
				# since we can't have both a postfix space and null
				$g++;
				$post = $code_space;
			}

			#
			# NULL optimization
			#
			elsif( $v[$g+1] == 0 )
			{
				$g++;
				$post = $code_null;
			}
		}

		$code = $code | $post;
		$output .= sprintf( ($code > 0x9f ? ", %03xh" : ",  %02xh"), $code );
	}

	print $label."; ".$db.substr($orig,2)."    ; uncompressed\n";
	print $label."  ".$db.substr($output,2);
	for( $t = length($output); $t < length($orig); $t++ )
	{
		print " ";
	}
	print "    ; compressed\n\n";
}

