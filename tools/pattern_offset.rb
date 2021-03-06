#!/usr/bin/env ruby
# $Id$
# $Revision$

$:.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rex'

if ARGV.length < 1 
	$stderr.puts("Usage: #{File.basename($0)} <search item> <length of buffer>")
	$stderr.puts("Default length of buffer if none is inserted: 8192")
	$stderr.puts("This buffer is generated by pattern_create() in the Rex library automatically")
	exit
end

value = ARGV.shift
len   = ARGV.shift || 8192

value  = value.hex if (value.length >= 8 and value.hex > 0)
buffer = Rex::Text.pattern_create(len.to_i)

offset = Rex::Text.pattern_offset(buffer, value)
while offset
	puts offset
	offset = Rex::Text.pattern_offset(buffer, value, offset + 1)
end
