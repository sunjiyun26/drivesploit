require 'msf/ui/console/command_dispatcher/encoder'
require 'msf/ui/console/command_dispatcher/exploit'
require 'msf/ui/console/command_dispatcher/nop'
require 'msf/ui/console/command_dispatcher/payload'
require 'msf/ui/console/command_dispatcher/auxiliary'

module Msf
module Ui
module Console
module CommandDispatcher

###
#
# Command dispatcher for core framework commands, such as module loading,
# session interaction, and other general things.
#
###
class Core

	include Msf::Ui::Console::CommandDispatcher

	# Session command options
	@@sessions_opts = Rex::Parser::Arguments.new(
		"-c" => [ true,  "Run a command on all live sessions"             ],
		"-h" => [ false, "Help banner."                                   ],
		"-i" => [ true,  "Interact with the supplied session identifier." ],
		"-l" => [ false, "List all active sessions."                      ],
		"-v" => [ false, "List verbose fields."                           ],
		"-q" => [ false, "Quiet mode."                                    ],
		"-d" => [ true,  "Detach an interactive session"                  ],
		"-k" => [ true,  "Terminate session."                             ],
		"-K" => [ false, "Terminate all sessions."                        ],
		"-s" => [ true,  "Run a script on all live meterpreter sessions"  ],
		"-u" => [ true,  "Upgrade a win32 shell to a meterpreter session" ])

	@@jobs_opts = Rex::Parser::Arguments.new(
		"-h" => [ false, "Help banner."                                   ],
		"-k" => [ true,  "Terminate the specified job name."              ],
		"-K" => [ false, "Terminate all running jobs."                    ],
		"-i" => [ true, "Lists detailed information about a running job." ],
		"-l" => [ false, "List all running jobs."                         ],
		"-v" => [ false, "Print more detailed info.  Use with -i and -l"  ])

	@@persist_opts = Rex::Parser::Arguments.new(
		"-s" => [ true,  "Storage medium to be used (ex: flatfile)."      ],
		"-r" => [ false, "Restore framework state."                       ],
		"-h" => [ false, "Help banner."                                   ])

	@@connect_opts = Rex::Parser::Arguments.new(
		"-h" => [ false, "Help banner."                                   ],
		"-p" => [ true,  "List of proxies to use."                        ],
		"-C" => [ false, "Try to use CRLF for EOL sequence."              ],
		"-c" => [ true,  "Specify which Comm to use."                     ],
		"-i" => [ true,  "Send the contents of a file."                   ],
		"-P" => [ true,  "Specify source port."                           ],
		"-S" => [ true,  "Specify source address."                        ],
		"-s" => [ false, "Connect with SSL."                              ],
		"-u" => [ false, "Switch to a UDP socket."                        ],
		"-w" => [ true,  "Specify connect timeout."                       ],
		"-z" => [ false, "Just try to connect, then return."              ])

	@@search_opts = Rex::Parser::Arguments.new(
		"-t" => [ true, "Type of module to search for (all|auxiliary|encoder|exploit|nop|payload)" ],
		"-r" => [ true, "Minimum rank to return (#{RankingName.sort.map{|r|r[1]}.join("|")})" ],
		"-h" => [ false, "Help banner."                                   ])


	# The list of data store elements that cannot be set when in defanged
	# mode.
	DefangedProhibitedDataStoreElements = [ "ModulePaths" ]

	# Returns the list of commands supported by this command dispatcher
	def commands
		{
			"?"        => "Help menu",
			"back"     => "Move back from the current context",
			"banner"   => "Display an awesome metasploit banner",
			"cd"       => "Change the current working directory",
			"connect"  => "Communicate with a host",
			"color"    => "Toggle color",
			"exit"     => "Exit the console",
			"help"     => "Help menu",
			"info"     => "Displays information about one or more module",
			"irb"      => "Drop into irb scripting mode",
			"jobs"     => "Displays and manages jobs",
			"kill"     => "kill a job",
			"load"     => "Load a framework plugin",

# XXX complete this before re-enabling
#			"persist"  => "Persist or restore framework state information",

			"loadpath" => "Searches for and loads modules from a path",
			"quit"     => "Exit the console",
			"resource" => "Run the commands stored in a file",
			"route"    => "Route traffic through a session",
			"save"     => "Saves the active datastores",
			"search"   => "Searches module names and descriptions",
			"sessions" => "Dump session listings and display information about sessions",
			"set"      => "Sets a variable to a value",
			"setg"     => "Sets a global variable to a value",
			"show"     => "Displays modules of a given type, or all modules",
			"sleep"    => "Do nothing for the specified number of seconds",
			"unload"   => "Unload a framework plugin",
			"unset"    => "Unsets one or more variables",
			"unsetg"   => "Unsets one or more global variables",
			"use"      => "Selects a module by name",
			"version"  => "Show the framework and console library version numbers",
		}
	end

	#
	# Initializes the datastore cache
	#
	def initialize(driver)
		super

		@dscache = {}
		@cache_payloads = nil
		@cache_active_module = nil
	end

	#
	# Returns the name of the command dispatcher.
	#
	def name
		"Core"
	end

	def cmd_color(*args)
		case args[0]
		when "auto"
			driver.output.auto_color
		when "true"
			driver.output.enable_color
		when "false"
			driver.output.disable_color
		else
			print_line("Usage: color <'true'|'false'|'auto'>\n")
			print_line("Enable or disable color output.")
			return
		end
		driver.update_prompt
	end

	def cmd_resource_tabs(str, words)
		tab_complete_filenames(str, words)
	end
	def cmd_resource(*args)
		if args.empty?
			print(
				"Usage: resource path1 path2 ...\n\n" +
				"Run the commands stored in the supplied files.\n")
			return false
		end
		args.each do |res|
			if not File.file? res
				print_error("#{res} is not a valid resource file")
				next
			end
			driver.load_resource(res)
		end
	end


	#
	# Pop the current dispatcher stack context, assuming it isn't pointed at
	# the core or database backend stack context.
	#
	def cmd_back(*args)
		if (driver.dispatcher_stack.size > 1 and
				driver.current_dispatcher.name != 'Core' and
				driver.current_dispatcher.name != 'Database Backend')
			# Reset the active module if we have one
			if (active_module)

				# Do NOT reset the UI anymore
				# active_module.reset_ui

				# Save the module's datastore so that we can load it later
				# if the module is used again
				@dscache[active_module.fullname] = active_module.datastore.dup

				self.active_module = nil
			end

			# Destack the current dispatcher
			driver.destack_dispatcher

			# Restore the prompt
			driver.update_prompt('')
		end
	end


	#
	# Change the current working directory
	#
	def cmd_cd(*args)
		if(args.length == 0)
			print_error("No path specified")
			return
		end

		begin
			Dir.chdir(args.join(" ").strip)
		rescue ::Exception
			print_error("The specified path does not exist")
		end
	end

	#
	# Display one of the fabulous banners.
	#
	def cmd_banner(*args)
		banner  = "%cya" + Banner.to_s + "%clr\n\n"
		banner << "       =[ %yelmetasploit v#{Msf::Framework::Version} [core:#{Msf::Framework::VersionCore} api:#{Msf::Framework::VersionAPI}]%clr\n"
		banner << "+ -- --=[ "
		banner << "#{framework.stats.num_exploits} exploits - #{framework.stats.num_auxiliary} auxiliary\n"
		banner << "+ -- --=[ "

		oldwarn = nil
		banner << "#{framework.stats.num_payloads} payloads - #{framework.stats.num_encoders} encoders - #{framework.stats.num_nops} nops\n"
		if ( ::Msf::Framework::RepoRevision.to_i > 0 and ::Msf::Framework::RepoUpdatedDate)
			tstamp = ::Msf::Framework::RepoUpdatedDate.strftime("%Y.%m.%d")
			banner << "       =[ svn r#{::Msf::Framework::RepoRevision} updated #{::Msf::Framework::RepoUpdatedDaysNote} (#{tstamp})\n"
			if(::Msf::Framework::RepoUpdatedDays > 7)
				oldwarn = []
				oldwarn << "Warning: This copy of the Metasploit Framework was last updated #{::Msf::Framework::RepoUpdatedDaysNote}."
				oldwarn << "         We recommend that you update the framework at least every other day."
				oldwarn << "         For information on updating your copy of Metasploit, please see:"
				oldwarn << "             http://www.metasploit.com/redmine/projects/framework/wiki/Updating"
				oldwarn << ""
			end
		end

		# Display the banner
		print_line(banner)

		if(oldwarn)
			oldwarn.map{|line| print_line(line) }
		end
	end

	#
	# Talk to a host
	#
	def cmd_connect(*args)
		if args.length < 2 or args.include?("-h")
			print(  "Usage: connect [options] <host> <port>\n\n" +
				"Communicate with a host, similar to interacting via netcat.\n" +
				@@connect_opts.usage)
			return false
		end

		crlf = false
		commval = nil
		fileval = nil
		proxies = nil
		srcaddr = nil
		srcport = nil
		ssl = false
		udp = false
		cto = nil
		justconn = false
		aidx = 0

		@@connect_opts.parse(args) do |opt, idx, val|
			case opt
				when "-C"
					crlf = true
					aidx = idx + 1
				when "-c"
					commval = val
					aidx = idx + 2
				when "-i"
					fileval = val
					aidx = idx + 2
				when "-P"
					srcport = val
					aidx = idx + 2
				when "-p"
					proxies = val
					aidx = idx + 2
				when "-S"
					srcaddr = val
					aidx = idx + 2
				when "-s"
					ssl = true
					aidx = idx + 1
				when "-w"
					cto = val.to_i
					aidx = idx + 2
				when "-u"
					udp = true
					aidx = idx + 1
				when "-z"
					justconn = true
					aidx = idx + 1
			end
		end

		commval = "Local" if commval =~ /local/i

		if fileval
			begin
				raise "Not a file" if File.ftype(fileval) != "file"
				infile = ::File.open(fileval)
			rescue
				print_error("Can't read from '#{fileval}': #{$!}")
				return false
			end
		end

		args = args[aidx .. -1]

		if args.length < 2
			print_error("You must specify a host and port")
			return false
		end

		host = args[0]
		port = args[1]

		comm = nil

		if commval
			begin
				if Rex::Socket::Comm.const_defined?(commval)
					comm = Rex::Socket::Comm.const_get(commval)
				end
			rescue NameError
			end

			if not comm
				session = framework.sessions.get(commval)

				if session.kind_of?(Msf::Session::Comm)
					comm = session
				end
			end

			if not comm
				print_error("Invalid comm '#{commval}' selected")
				return false
			end
		end

		begin
			klass = udp ? ::Rex::Socket::Udp : ::Rex::Socket::Tcp
			sock = klass.create({
				'Comm'      => comm,
				'Proxies'   => proxies,
				'SSL'       => ssl,
				'PeerHost'  => host,
				'PeerPort'  => port,
				'LocalHost' => srcaddr,
				'LocalPort' => srcport,
				'Timeout'   => cto,
				'Context'   => {
					'Msf' => framework
				}
			})
		rescue
			print_error("Unable to connect: #{$!}")
			return false
		end

		print_status("Connected to #{host}:#{port}")

		if justconn
			sock.close
			infile.close if infile
			return true
		end

		cin = infile || driver.input
		cout = driver.output

		begin
			# Console -> Network
			c2n = Thread.new(cin, sock) do |input, output|
				while true
					begin
						res = input.gets
						break if not res
						if crlf and (res =~ /^\n$/ or res =~ /[^\r]\n$/)
							res.gsub!(/\n$/, "\r\n")
						end
						output.write res
					rescue ::EOFError, ::IOError
						break
					end
				end
			end

			# Network -> Console
			n2c = ::Thread.new(sock, cout, c2n) do |input, output, cthr|
				while true
					begin
						res = input.read(65535)
						break if not res
						output.print res
					rescue ::EOFError, ::IOError
						break
					end
				end

				Thread.kill(cthr)
			end

			c2n.join

		rescue ::Interrupt
			c2n.kill
			n2c.kill
		end


		sock.close rescue nil
		infile.close if infile

		true
	end

	#
	# Instructs the driver to stop executing.
	#
	def cmd_exit(*args)
		forced = false
		forced = true if (args[0] and args[0] =~ /-y/i)

		if(framework.sessions.length > 0 and not forced)
			print_status("You have active sessions open, to exit anyway type \"exit -y\"")
			return
		end

		driver.stop
	end

	alias cmd_quit cmd_exit

	#
	# Causes process to pause for the specified number of seconds
	#
	def cmd_sleep(*args)
		return if not (args and args.length == 1)
		Rex::ThreadSafe.sleep(args[0].to_f)
	end

	#
	# Displays the command help banner or an individual command's help banner
	# if we can figure out how to invoke it.
	#
	def cmd_help(*args)
		if args and args.length > 0 and commands.include?(args[0])
			if self.respond_to? "cmd_"+ args[0] + "_help"
				self.send("cmd_"+ args[0] + "_help")
			else
				#
				# This part is done in a hackish way because not all of the
				# usage info is available from self.commands() or @@*_opts, so
				# we check @@<cmd>_opts for "-h".  It's non-optimal because
				# several commands have usage info, but don't use -h to invoke
				# it.
				begin
					opts = eval("@@" + args[0] + "_opts")
				rescue
				end
				if opts and opts.include?("-h")
					self.send("cmd_" + args[0], "-h")
				else
					print_line("No help available for #{args[0]}")
				end
			end
		else
			print(driver.help_to_s)
		end
	end
	def cmd_help_tabs(str, words)
		return commands.keys
	end


	alias cmd_? cmd_help

	#
	# Displays information about one or more module.
	#
	def cmd_info(*args)
		if (args.length == 0)
			if (active_module)
				print(Serializer::ReadableText.dump_module(active_module))
				return true
			else
				print(
					"Usage: info mod1 mod2 mod3 ...\n\n" +
					"Queries the supplied module or modules for information.\n")
				return false
			end
		end

		args.each { |name|
			mod = framework.modules.create(name)

			if (mod == nil)
				print_error("Invalid module: #{name}")
			else
				print(Serializer::ReadableText.dump_module(mod))
			end
		}
	end

	#
	# Tab completion for the info command (same as use)
	#
	def cmd_info_tabs(str, words)
		cmd_use_tabs(str, words)
	end

	#
	# Goes into IRB scripting mode
	#
	def cmd_irb(*args)
		defanged?

		print_status("Starting IRB shell...\n")

		begin
			Rex::Ui::Text::IrbShell.new(binding).run
		rescue
			print_error("Error during IRB: #{$!}\n\n#{$@.join("\n")}")
		end

		# Reset tab completion
		if (driver.input.supports_readline)
			driver.input.reset_tab_completion
		end
	end

	#
	# Displays and manages running jobs for the active instance of the
	# framework.
	#
	def cmd_jobs(*args)
		# Make the default behavior listing all jobs if there were no options
		# or the only option is the verbose flag
		if (args.length == 0 or args == ["-v"])
			args.unshift("-l")
		end

		verbose = false
		dump_list = false
		dump_info = false
		job_id = nil

		# Parse the command options
		@@jobs_opts.parse(args) { |opt, idx, val|
			case opt
				when "-v"
					verbose = true
				when "-l"
					dump_list = true

				# Terminate the supplied job name
				when "-k"
					if (not framework.jobs.has_key?(val))
						print_error("No such job")
					else
						print_line("Stopping job: #{val}...")
						framework.jobs.stop_job(val)
					end
				when "-K"
					print_line("Stopping all jobs...")
					framework.jobs.each_key do |i|
						framework.jobs.stop_job(i)
					end
				when "-i"
					# Defer printing anything until the end of option parsing
					# so we can check for the verbose flag.
					dump_info = true
					job_id = val
				when "-h"
					print(
						"Usage: jobs [options]\n\n" +
						"Active job manipulation and interaction.\n" +
						@@jobs_opts.usage())
					return false
			end
		}

		if (dump_list)
			print("\n" + Serializer::ReadableText.dump_jobs(framework, verbose) + "\n")
		end
		if (dump_info)
			if (job_id and framework.jobs[job_id.to_s])
				job = framework.jobs[job_id.to_s]
				mod = job.ctx[0]

				output  = "\n"
				output += "Name: #{mod.name}"
				output += ", started at #{job.start_time}" if job.start_time
				print_line(output)

				if (mod.options.has_options?)
					show_options(mod)
				end

				if (verbose)
					mod_opt = Serializer::ReadableText.dump_advanced_options(mod,'   ')
					print_line("\nModule advanced options:\n\n#{mod_opt}\n") if (mod_opt and mod_opt.length > 0)
				end
			else
				print_line("Invalid Job ID")
			end
		end
	end

	#
	# Tab completion for the jobs command
	#
	def cmd_jobs_tabs(str, words)
		if(not words[1])
			return %w{-l -k -K -h -v}
		end
		if (words[1] == '-k' and not words[2])
			# XXX return the list of job values
			return framework.jobs.keys
		end
	end

	def cmd_kill(*args)
		cmd_jobs("-k", *args)
	end

	def cmd_kill_tabs(str, words)
		return framework.jobs.keys if not words[1]
	end

	#
	# Loads a plugin from the supplied path.  If no absolute path is supplied,
	# the framework root plugin directory is used.
	#
	def cmd_load(*args)
		defanged?

		if (args.length == 0)
			print_line(
				"Usage: load <path> [var=val var=val ...]\n\n" +
				"Load a plugin from the supplied path.  The optional\n" +
				"var=val options are custom parameters that can be\n" +
				"passed to plugins.")
			return false
		end

		# Default to the supplied argument path.
		path = args.shift
		opts  = {
			'LocalInput'    => driver.input,
			'LocalOutput'   => driver.output,
			'ConsoleDriver' => driver
			}

		# Parse any extra options that should be passed to the plugin
		args.each { |opt|
			k, v = opt.split(/=/)

			opts[k] = v if (k and v)
		}

		# If no absolute path was supplied, check the base and user plugin directories
		if (path !~ /#{File::SEPARATOR}/)
			plugin_file_name = path

			# If the plugin isn't in the user direcotry (~/.msf3/plugins/), use the base
			path = Msf::Config.user_plugin_directory + File::SEPARATOR + plugin_file_name
			if not File.exists?( path  + ".rb" )
				# If the following "path" doesn't exist it will be caught when we attempt to load
				path = Msf::Config.plugin_directory + File::SEPARATOR + plugin_file_name
			end

		end

		# Load that plugin!
		begin
			if (inst = framework.plugins.load(path, opts))
				print_status("Successfully loaded plugin: #{inst.name}")
			end
		rescue ::Exception => e
			elog("Error loading plugin #{path}: #{e}\n\n#{e.backtrace.join("\n")}", src = 'core', level = 0, from = caller)
			print_error("Failed to load plugin from #{path}: #{e}")
		end
	end

	#
	# Tab completion for the load command
	#
	def cmd_load_tabs(str, words)
		if(not words[1] or not words[1].match(/^\//))
			begin
				return Dir.new(Msf::Config.plugin_directory).find_all { |e|
					path = Msf::Config.plugin_directory + File::SEPARATOR + e
					File.file?(path) and File.readable?(path)
				}.map { |e|
					e.sub!(/\.rb$/, '')
				}
			rescue Exception
			end
		end
	end

	#
	# This method persists or restores framework state from a persistent
	# storage medium, such as a flatfile.
	#
	def cmd_persist(*args)
		defanged?

		if (args.length == 0)
			args.unshift("-h")
		end

		arg_idx = 0
		restore = false
		storage = 'flatfile'

		@@persist_opts.parse(args) { |opt, idx, val|
			case opt
				when "-s"
					storage = val
					arg_idx = idx + 2
				when "-r"
					restore = true
					arg_idx = idx + 1
				when "-h"
					print(
						"Usage: persist [-r] -s storage arg1 arg2 arg3 ...\n\n" +
						"Persist or restore framework state information.\n" +
						@@persist_opts.usage())
					return false
			end
		}

		# Chop off all the non-arguments
		args = args[arg_idx..-1]

		begin
			if (inst = Msf::PersistentStorage.create(storage, *args))
				inst.store(framework)
			else
				print_error("Failed to find storage medium named '#{storage}'")
			end
		rescue
			log_error("Failed to persist to #{storage}: #{$!}")
		end
	end

	#
	# Tab completion for the persist command
	#
	def cmd_persist_tabs(str, words)
		if (not words[1])
			return %w{-s -r -h}
		end
	end

	#
	# This method handles the route command which allows a user to specify
	# which session a given subnet should route through.
	#
	def cmd_route(*args)
		if (args.length == 0)
			print(
				"Usage: route [add/remove/get/flush/print] subnet netmask [comm/sid]\n\n" +
				"Route traffic destined to a given subnet through a supplied session. \n" +
				"The default comm is Local.\n")
			return false
		end

		case args.shift
			when "add"
				if (args.length < 3)
					print_error("Missing arguments to route add.")
					return false
				end

				gw = nil

				# Satisfy case problems
				args[2] = "Local" if (args[2] =~ /local/i)

				begin
					# If the supplied gateway is a global Comm, use it.
					if (Rex::Socket::Comm.const_defined?(args[2]))
						gw = Rex::Socket::Comm.const_get(args[2])
					end
				rescue NameError
				end

				# If we still don't have a gateway, check if it's a session.
				if ((gw == nil) and
						(session = framework.sessions.get(args[2])) and
						(session.kind_of?(Msf::Session::Comm)))
					gw = session
				elsif (gw == nil)
					print_error("Invalid gateway specified.")
					return false
				end

				Rex::Socket::SwitchBoard.add_route(
					args[0],
					args[1],
					gw)
			when "remove"
				if (args.length < 3)
					print_error("Missing arguments to route remove.")
					return false
				end

				gw = nil

				# Satisfy case problems
				args[2] = "Local" if (args[2] =~ /local/i)

				begin
					# If the supplied gateway is a global Comm, use it.
					if (Rex::Socket::Comm.const_defined?(args[2]))
						gw = Rex::Socket::Comm.const_get(args[2])
					end
				rescue NameError
				end

				# If we still don't have a gateway, check if it's a session.
				if ((gw == nil) and
						(session = framework.sessions.get(args[2])) and
						(session.kind_of?(Msf::Session::Comm)))
					gw = session
				elsif (gw == nil)
					print_error("Invalid gateway specified.")
					return false
				end

				Rex::Socket::SwitchBoard.remove_route(
					args[0],
					args[1],
					gw)
			when "get"
				if (args.length == 0)
					print_error("You must supply an IP address.")
					return false
				end

				comm = Rex::Socket::SwitchBoard.best_comm(args[0])

				if ((comm) and
						(comm.kind_of?(Msf::Session)))
					print_line("#{args[0]} routes through: Session #{comm.sid}")
				else
					print_line("#{args[0]} routes through: Local")
				end
			when "flush"
				Rex::Socket::SwitchBoard.flush_routes
			when "print"
				tbl =	Table.new(
					Table::Style::Default,
					'Header'  => "Active Routing Table",
					'Prefix'  => "\n",
					'Postfix' => "\n",
					'Columns' =>
						[
							'Subnet',
							'Netmask',
							'Gateway',
						],
					'ColProps' =>
						{
							'Subnet'  => { 'MaxWidth' => 17 },
							'Netmask' => { 'MaxWidth' => 17 },
						})

				Rex::Socket::SwitchBoard.each { |route|

					if (route.comm.kind_of?(Msf::Session))
						gw = "Session #{route.comm.sid}"
					else
						gw = route.comm.name.split(/::/)[-1]
					end

					tbl << [ route.subnet, route.netmask, gw ]
				}

				print(tbl.to_s)
		end
	end

	#
	# Tab completion for the route command
	#
	def cmd_route_tabs(str, words)
		if (not words[1])
			return %w{add remove get flush print}
		end
	end

	#
	# Saves the active datastore contents to disk for automatic use across
	# restarts of the console.
	#
	def cmd_save(*args)
		defanged?

		# Save the console config
		driver.save_config

		# Save the framework's datastore
		begin
			framework.save_config

			if (active_module)
				active_module.save_config
			end
		rescue
			log_error("Save failed: #{$!}")
			return false
		end

		print_line("Saved configuration to: #{Msf::Config.config_file}")
	end

	#
	# Adds one or more search paths.
	#
	def cmd_loadpath(*args)
		defanged?

		if (args.length == 0)
			print_error("No search paths were provided.")
			return true
		end

		totals    = {}
		overall   = 0
		curr_path = nil

		begin
			# Walk the list of supplied search paths attempting to add each one
			# along the way
			args.each { |path|
				curr_path = path

				# Load modules, but do not consult the cache
				if (counts = framework.modules.add_module_path(path, false))
					counts.each_pair { |type, count|
						totals[type] = (totals[type]) ? (totals[type] + count) : count

						overall += count
					}
				end
			}
		rescue NameError, RuntimeError
			log_error("Failed to add search path #{curr_path}: #{$!}")
			return true
		end

		added = "Loaded #{overall} modules:\n"

		totals.each_pair { |type, count|
			added << "    #{count} #{type}#{count != 1 ? 's' : ''}\n"
		}

		print(added)
	end

	def cmd_loadpath_tabs(str, words)
		paths = []
		if (File.directory?(str))
			paths = Dir.entries(str)
			paths = paths.map { |f|
				if File.directory? File.join(str,f)
					File.join(str,f)
				end
			}
			paths.delete_if { |f| f.nil? or File.basename(f) == '.' or File.basename(f) == '..' }
		else
			d = Dir.glob(str + "*").map { |f| f if File.directory?(f) }
			d.delete_if { |f| f.nil? or f == '.' or f == '..' }
			# If there's only one possibility, descend to the next level
			if (1 == d.length)
				paths = Dir.entries(d[0])
				paths = paths.map { |f|
					if File.directory? File.join(d[0],f)
						File.join(d[0],f)
					end
				}
				paths.delete_if { |f| f.nil? or File.basename(f) == '.' or File.basename(f) == '..' }
			else
				paths = d
			end
		end
		paths.sort!
		return paths
	end

	#
	# Searches modules (name and description) for specified regex
	#
	def cmd_search(*args)
		section = 'all'
		rank    = 'manual'
		match   = nil
		@@search_opts.parse(args) { |opt, idx, val|
			case opt
			when "-h"
				print_line("Usage: search [options] [regex]")
				print(@@search_opts.usage)
				return
			when "-t"
				section = val
			when "-r"
				rank = val
			else
				match = val
			end
		}
		match = '.*' if match.nil?

		begin
			regex = Regexp.new(match, true, 'n')
		rescue RegexpError => e
			print_error("Invalid regular expression: #{match} (hint: try .*)")
			return
		end

		print_status("Searching loaded modules for pattern '#{match}'...")

		if rank.to_i != 0
			rank = rank.to_i
		elsif RankingName.has_value? rank
			rank = RankingName.invert[rank]
		else
			print_error("Invalid rank, should be one of: " + RankingName.sort.map{|r| r[1]}.join(", "))
			return
		end

		case section
		when 'all'
			show_auxiliary(regex, rank)
			show_encoders(regex, rank)
			show_exploits(regex, rank)
			show_nops(regex)
			show_payloads(regex)
		when 'auxiliary'
			show_auxiliary(regex, rank)
		when 'encoder'
			show_encoders(regex, rank)
		when 'exploit'
			show_exploits(regex, rank)
		when 'nop'
			show_nops(regex)
		when 'payload'
			show_payloads(regex)
		end
	end

	def cmd_search_tabs(str, words)
		case (words[-1])
		when "-r"
			return RankingName.sort.map{|r| r[1]}
		when "-t"
			return %w{auxiliary encoder exploit nop payload}
		else
			return ["-h", "-r", "-t"]
		end
	end

	#
	#
	# Provides an interface to the sessions currently active in the framework.
	#
	def cmd_sessions(*args)
		begin
		method  = 'list'
		quiet   = false
		verbose = false
		sid     = nil
		cmds    = []
		script  = nil

		# Parse the command options
		@@sessions_opts.parse(args) { |opt, idx, val|
			case opt
				when "-q"
					quiet = true

				# Run a command on all sessions
				when "-c"
					method = 'cmd'
					if (val)
						cmds << val
					end

				when "-v"
					verbose = true

				# Interact with the supplied session identifier
				when "-i"
					method = 'interact'
					sid = val

				# Display the list of active sessions
				when "-l"
					method = 'list'

				when "-k"
					method = 'kill'
					sid = val

				when "-K"
					method = 'killall'

				when "-d"
					method = 'detach'
					sid = val

				# Run a script on all meterpreter sessions
				when "-s"
					if  not script
						method = 'scriptall'
						script = val
					end


				# Upload and exec to the specific command session
				when "-u"
					method = 'upexec'
					sid = val

				# Display help banner
				when "-h"
					print(
						"Usage: sessions [options]\n\n" +
						"Active session manipulation and interaction.\n" +
						@@sessions_opts.usage())
					return false
			end
		}

		# Now, perform the actual method
		case method

			when 'cmd'
				if (cmds.length > 0)
					cmds.each do |cmd|
						framework.sessions.each_sorted do |s|
							session = framework.sessions.get(s)
							print_status("Running '#{cmd}' on session #{s} (#{session.tunnel_peer})")

							if (session.type == "meterpreter")
								# If session.sys is nil, dont even try..
								if not (session.sys)
									print_error("Session #{s} does not have stdapi loaded, skipping...")
									next
								end
								c,args = cmd.split(' ', 2)
								begin
									process = session.sys.process.execute(c, args,
										{
											'Channelized' => true,
											'Hidden'      => true
										})
								rescue ::Rex::Post::Meterpreter::RequestError
									print_error("Failed: #{$!.class} #{$!}")
								end
								if process and process.channel and (data = process.channel.read)
									print_line(data)
								end
							elsif session.type == "shell"
								if (output = session.shell_command(cmd))
									print_line(output)
								end
							end
							# If the session isn't a meterpreter or shell type, it
							# could be a VNC session (which can't run commands) or
							# something custom (which we don't know how to run
							# commands on), so don't bother.
						end
					end
				else
					print_error("No command specified!")
				end

			when 'kill'
				if ((session = framework.sessions.get(sid)))
					print_status("Killing session #{sid}")
					session.kill
				else
					print_error("Invalid session identifier: #{sid}")
				end

			when 'killall'
				print_status("Killing all sessions...")
				framework.sessions.each_sorted do |s|
					if ((session = framework.sessions.get(s)))
						session.kill
					end
				end

			when 'detach'
				if ((session = framework.sessions.get(sid)))
					print_status("Detaching session #{sid}")
					if (session.interactive?)
						session.detach()
					end
				else
					print_error("Invalid session identifier: #{sid}")
				end

			when 'interact'
				if ((session = framework.sessions.get(sid)))
					if (session.interactive?)
						print_status("Starting interaction with #{session.name}...\n") if (quiet == false)

						self.active_session = session

						session.interact(driver.input.dup, driver.output)

						self.active_session = nil

						if (driver.input.supports_readline)
							driver.input.reset_tab_completion
						end

					else
						print_error("Session #{sid} is non-interactive.")
					end
				else
					print_error("Invalid session identifier: #{sid}")
				end

			when 'list'
				print("\n" +
					Serializer::ReadableText.dump_sessions(framework, verbose) + "\n")

			when 'scriptall'
				if (not script.nil?)
					sleep(0.5)
					script_path = Msf::Sessions::Meterpreter.find_script_path(script)
					if (not script_path.nil?)
						print_status("Running script #{script} on all meterpreter sessions ...")
						framework.sessions.each_sorted do |s|
							if ((session = framework.sessions.get(s)))
								if (session.type == "meterpreter")
									print_status("Session #{s} (#{session.tunnel_peer}):")
									begin
										session.execute_file(script_path, args.slice(2,args.length))
									rescue ::Exception => e
										log_error("Error executing script: #{e.class} #{e}")
									end
								end
							end
						end
					else
						print_error("The specified script \"#{script}\" does not exist.")
					end
				else
					print_error("No script specified!")
				end

			when 'upexec'
				if ((session = framework.sessions.get(sid)))
					if (session.interactive?)
						if (session.type == "shell") # XXX: check for windows?
							session.init_ui(driver.input, driver.output)
							session.execute_script('spawn_meterpreter', nil)
							session.reset_ui
						else
							print_error("Session #{sid} is not a command shell session.")
						end
					else
						print_error("Session #{sid} is non-interactive.")
					end
				else
					print_error("Invalid session identifier: #{sid}")
				end

		end

		rescue IOError, EOFError, Rex::StreamClosedError
			print_status("Session stream closed.")
		rescue ::Interrupt
			raise $!
		rescue ::Exception
			log_error("Session manipulation failed: #{$!} #{$!.backtrace.inspect}")
		end

		# Reset the active session
		self.active_session = nil

		return true
	end

	#
	# Tab completion for the sessions command
	#
	def cmd_sessions_tabs(str, words)
		if (not words[1])
			return %w{-q -i -l -h}
		end
	end

	#
	# Sets a name to a value in a context aware environment.
	#
	def cmd_set(*args)

		# Figure out if these are global variables
		global = false

		if (args[0] == '-g')
			args.shift
			global = true
		end

		# Determine which data store we're operating on
		if (active_module and global == false)
			datastore = active_module.datastore
		else
			global = true
			datastore = self.framework.datastore
		end

		# Dump the contents of the active datastore if no args were supplied
		if (args.length == 0)
			# If we aren't dumping the global data store, then go ahead and
			# dump it first
			if (!global)
				print("\n" +
					Msf::Serializer::ReadableText.dump_datastore(
						"Global", framework.datastore))
			end

			# Dump the active datastore
			print("\n" +
				Msf::Serializer::ReadableText.dump_datastore(
					(global) ? "Global" : "Module: #{active_module.refname}",
					datastore) + "\n")
			return true
		elsif (args.length == 1)
			if (not datastore[args[0]].nil?)
				print_line("#{args[0]} => #{datastore[args[0]]}")
				return true
			else
				print_error("Unknown variable")
				print(
					"Usage: set name value\n\n" +
					"Sets an arbitrary name to an arbitrary value.\n")
				return false
			end
		end

		# Set the supplied name to the supplied value
		name  = args[0]
		value = args[1, args.length-1].join(' ')

		# Security check -- make sure the data store element they are setting
		# is not prohibited
		if global and DefangedProhibitedDataStoreElements.include?(name)
			defanged?
		end

		# If the driver indicates that the value is not valid, bust out.
		if (driver.on_variable_set(global, name, value) == false)
			print_error("The value specified for #{name} is not valid.")
			return true
		end

		datastore[name] = value

		print_line("#{name} => #{value}")
	end

	#
	# Tab completion for the set command
	#
	def cmd_set_tabs(str, words)

		# A value has already been specified
		if (words[2])
			return nil
		end

		# A value needs to be specified
		if(words[1])
			return tab_complete_option(str, words)
		end

		res = cmd_unset_tabs(str, words) || [ ]
		# There needs to be a better way to register global options, but for
		# now all we have is an ad-hoc list of opts that the shell treats
		# specially.
		res += %w{
			ConsoleLogging
			LogLevel
			MinimumRank
			SessionLogging
			TimestampOutput
		}
		mod = active_module

		if (not mod)
			return res
		end

		mod.options.sorted.each { |e|
			name, opt = e
			res << name
		}

		# Exploits provide these three default options
		if (mod.exploit?)
			res << 'PAYLOAD'
			res << 'NOP'
			res << 'TARGET'
		end
		if (mod.exploit? or mod.payload?)
			res << 'ENCODER'
		end

		if (mod.auxiliary?)
			res << "ACTION"
		end

		if (mod.exploit? and mod.datastore['PAYLOAD'])
			p = framework.modules.create(mod.datastore['PAYLOAD'])
			if (p)
				p.options.sorted.each { |e|
					name, opt = e
					res << name
				}
			end
		end

		return res
	end


	#
	# Sets the supplied variables in the global datastore.
	#
	def cmd_setg(*args)
		args.unshift('-g')

		cmd_set(*args)
	end

	#
	# Tab completion for the setg command
	#
	def cmd_setg_tabs(str, words)
		res = cmd_set_tabs(str, words) || [ ]
	end

	#
	# Displays the list of modules based on their type, or all modules if
	# no type is provided.
	#
	def cmd_show(*args)
		mod = self.active_module

		args << "all" if (args.length == 0)

		args.each { |type|
			case type
				when 'all'
					show_encoders
					show_nops
					show_exploits
					show_payloads
					show_auxiliary
					show_plugins
				when 'encoders'
					show_encoders
				when 'nops'
					show_nops
				when 'exploits'
					show_exploits
				when 'payloads'
					show_payloads
				when 'auxiliary'
					show_auxiliary
				when 'options'
					if (mod)
						show_options(mod)
					else
						show_global_options
					end
				when 'advanced'
					if (mod)
						show_advanced_options(mod)
					else
						print_error("No module selected.")
					end
				when 'evasion'
					if (mod)
						show_evasion_options(mod)
					else
						print_error("No module selected.")
					end
				when "plugins"
					show_plugins
				when "targets"
					if (mod and mod.exploit?)
						show_targets(mod)
					else
						print_error("No exploit module selected.")
					end
				when "actions"
					if (mod and mod.auxiliary?)
						show_actions(mod)
					else
						print_error("No auxiliary module selected.")
					end
			end
		}
	end

	#
	# Tab completion for the show command
	#
	def cmd_show_tabs(str, words)
		res = %w{all encoders nops exploits payloads auxiliary plugins options}
		if (active_module)
			res.concat(%w{ advanced evasion targets actions })
		end
		return res
	end

	#
	# Unloads a plugin by its name.
	#
	def cmd_unload(*args)
		if (args.length == 0)
			print_line(
				"Usage: unload [plugin name]\n\n" +
				"Unloads a plugin by its symbolic name.")
			return false
		end

		# Walk the plugins array
		framework.plugins.each { |plugin|
			# Unload the plugin if it matches the name we're searching for
			if (plugin.name == args[0])
				print("Unloading plugin #{args[0]}...")
				framework.plugins.unload(plugin)
				print_line("unloaded.")
				break
			end
		}
	end

	#
	# Tab completion for the unload command
	#
	def cmd_unload_tabs(str, words)
		tabs = []
		framework.plugins.each { |k| tabs.push(k.name) }
		return tabs
	end

	#
	# Unsets a value if it's been set.
	#
	def cmd_unset(*args)

		# Figure out if these are global variables
		global = false

		if (args[0] == '-g')
			args.shift
			global = true
		end

		# Determine which data store we're operating on
		if (active_module and global == false)
			datastore = active_module.datastore
		else
			datastore = framework.datastore
		end

		# No arguments?  No cookie.
		if (args.length == 0)
			print(
				"Usage: unset var1 var2 var3 ...\n\n" +
				"The unset command is used to unset one or more variables.\n" +
				"To flush all entires, specify 'all' as the variable name\n")

			return false
		end

		# If all was specified, then flush all of the entries
		if args[0] == 'all'
			print_line("Flushing datastore...")

			# Re-import default options into the module's datastore
			if (active_module and global == false)
				active_module.import_defaults
			# Or simply clear the global datastore
			else
				datastore.clear
			end

			return true
		end

		while ((val = args.shift))
			if (driver.on_variable_unset(global, val) == false)
				print_error("The variable #{val} cannot be unset at this time.")
				next
			end

			print_line("Unsetting #{val}...")

			datastore.delete(val)
		end
	end

	#
	# Tab completion for the unset command
	#
	def cmd_unset_tabs(str, words)
		datastore = active_module ? active_module.datastore : self.framework.datastore
		datastore.keys
	end

	#
	# Unsets variables in the global data store.
	#
	def cmd_unsetg(*args)
		args.unshift('-g')

		cmd_unset(*args)
	end

	#
	# Tab completion for the unsetg command
	#
	def cmd_unsetg_tabs(str, words)
		self.framework.datastore.keys
	end

	#
	# Uses a module.
	#
	def cmd_use(*args)
		if (args.length == 0)
			print(
				"Usage: use module_name\n\n" +
				"The use command is used to interact with a module of a given name.\n")
			return false
		end

		# Try to create an instance of the supplied module name
		mod_name = args[0]

		begin
			if ((mod = framework.modules.create(mod_name)) == nil)
				print_error("Failed to load module: #{mod_name}")
				return false
			end
		rescue Rex::AmbiguousArgumentError => info
			print_error(info.to_s)
		rescue NameError => info
			log_error("The supplied module name is ambiguous: #{$!}.")
		end

		return false if (mod == nil)

		# Enstack the command dispatcher for this module type
		dispatcher = nil

		case mod.type
			when MODULE_ENCODER
				dispatcher = Encoder
			when MODULE_EXPLOIT
				dispatcher = Exploit
			when MODULE_NOP
				dispatcher = Nop
			when MODULE_PAYLOAD
				dispatcher = Payload
			when MODULE_AUX
				dispatcher = Auxiliary
			else
				print_error("Unsupported module type: #{mod.type}")
				return false
		end

		# If there's currently an active module, go back
		if (active_module)
			cmd_back()
		end

		if (dispatcher != nil)
			driver.enstack_dispatcher(dispatcher)
		end

		# Update the active module
		self.active_module = mod

		# If a datastore cache exists for this module, then load it up
		if @dscache[active_module.fullname]
			active_module.datastore.update(@dscache[active_module.fullname])
		end

		mod.init_ui(driver.input, driver.output)

		# Update the command prompt
		driver.update_prompt("#{mod.type}(%bld%red#{mod.shortname}%clr) ")
	end

	#
	# Tab completion for the use command
	#
	def cmd_use_tabs(str, words)
		res = []

		framework.modules.module_types.each do |mtyp|
			mset = framework.modules.module_names(mtyp)
			mset.each do |mref|
				res << mtyp + '/' + mref
			end
		end

		return res.sort
	end

	#
	# Returns the revision of the framework and console library
	#
	def cmd_version(*args)
		ver = "$Revision$"

		print_line("Framework: #{Msf::Framework::Version}.#{Msf::Framework::Revision.match(/ (.+?) \$/)[1]}")
		print_line("Console  : #{Msf::Framework::Version}.#{ver.match(/ (.+?) \$/)[1]}")

		return true
	end

	#
	# Provide tab completion for option values
	#
	def tab_complete_option(str, words)
		opt = words[1]
		res = []
		mod = active_module

		# With no active module, we have nothing to compare
		if (not mod)
			return res
		end

		# Well-known option names specific to exploits
		if (mod.exploit?)
			return option_values_payloads() if opt.upcase == 'PAYLOAD'
			return option_values_targets()  if opt.upcase == 'TARGET'
			return option_values_nops()     if opt.upcase == 'NOPS'
		end

		# Well-known option names specific to auxiliaries
		if (mod.auxiliary?)
			return option_values_actions() if opt.upcase == 'ACTION'
		end

		# The ENCODER option works for payloads and exploits
		if ((mod.exploit? or mod.payload?) and opt.upcase == 'ENCODER')
			return option_values_encoders()
		end

		# Is this option used by the active module?
		if (mod.options.include?(opt))
			res.concat(option_values_dispatch(mod.options[opt], str, words))
		end

		# How about the selected payload?
		if (mod.exploit? and mod.datastore['PAYLOAD'])
			p = framework.modules.create(mod.datastore['PAYLOAD'])
			if (p and p.options.include?(opt))
				res.concat(option_values_dispatch(p.options[opt], str, words))
			end
		end

		return res
	end

	#
	# Provide possible option values based on type
	#
	def option_values_dispatch(o, str, words)

		res = []
		res << o.default.to_s if o.default

		case o.class.to_s

			when 'Msf::OptAddress'
				case o.name.upcase
					when 'RHOST'
						option_values_target_addrs().each do |addr|
							res << addr
						end
					when 'LHOST'
						res << Rex::Socket.source_address()
					else
				end

			when 'Msf::OptAddressRange'

				case str
					when /\/$/
						res << str+'32'
						res << str+'24'
						res << str+'16'
					when /\-$/
						res << str+str[0, str.length - 1]
					else
						option_values_target_addrs().each do |addr|
							res << addr+'/32'
							res << addr+'/24'
							res << addr+'/16'
						end
				end

			when 'Msf::OptPort'
				case o.name.upcase
					when 'RPORT'
					option_values_target_ports().each do |port|
						res << port
					end
				end

				if (res.empty?)
					res << (rand(65534)+1).to_s
				end

			when 'Msf::OptEnum'
				o.enums.each do |val|
					res << val
				end
			when 'Msf::OptPath'
				files = tab_complete_filenames(str,words)
				res += files if files
		end

		return res
	end

	#
	# Provide valid payload options for the current exploit
	#
	def option_values_payloads

		# Module caching for significant speed improvement
		if (not (@cache_active_module and @cache_active_module == active_module.refname))
			@cache_active_module = active_module.refname
			@cache_payloads = active_module.compatible_payloads.map { |refname, payload| refname }
		end

		@cache_payloads
	end

	#
	# Provide valid target options for the current exploit
	#
	def option_values_targets
		res = []
		if (active_module.targets)
			1.upto(active_module.targets.length) { |i| res << (i-1).to_s }
		end
		return res
	end


	#
	# Provide valid action options for the current auxiliary module
	#
	def option_values_actions
		res = []
		if (active_module.actions)
			active_module.actions.each { |i| res << i.name }
		end
		return res
	end

	#
	# Provide valid nops options for the current exploit
	#
	def option_values_nops
		framework.nops.map { |refname, mod| refname }
	end

	#
	# Provide valid encoders options for the current exploit or payload
	#
	def option_values_encoders
		framework.encoders.map { |refname, mod| refname }
	end

	#
	# Provide the target addresses
	#
	def option_values_target_addrs
		res = [ ]
		res << Rex::Socket.source_address()
		return res if not framework.db.active

		# List only those hosts with matching open ports?
		mport = self.active_module.datastore['RPORT']
		if (mport)
			mport = mport.to_i
			hosts = {}
			framework.db.each_service do |service|
				if (service.port == mport)
					hosts[ service.host.address ] = true
				end
			end

			hosts.keys.each do |host|
				res << host
			end

		# List all hosts in the database
		else
			framework.db.each_host do |host|
				res << host.address
			end
		end

		return res
	end

	#
	# Provide the target ports
	#
	def option_values_target_ports
		res = [ ]
		return res if not framework.db.active
		return res if not self.active_module.datastore['RHOST']
		host = framework.db.has_host?(self.active_module.datastore['RHOST'])
		return res if not host

		framework.db.each_service do |service|
			if (service.host_id == host.id)
				res << service.port.to_s
			end
		end

		return res
	end

protected

	#
	# Module list enumeration
	#

	def show_encoders(regex = nil, minrank = nil) # :nodoc:
		# If an active module has been selected and it's an exploit, get the
		# list of compatible encoders and display them
		if (active_module and active_module.exploit? == true)
			show_module_set("Compatible Encoders", active_module.compatible_encoders, regex, minrank)
		else
			show_module_set("Encoders", framework.encoders, regex, minrank)
		end
	end

	def show_nops(regex = nil) # :nodoc:
		show_module_set("NOP Generators", framework.nops, regex)
	end

	def show_exploits(regex = nil, minrank = nil) # :nodoc:
		show_module_set("Exploits", framework.exploits, regex, minrank)
	end

	def show_payloads(regex = nil) # :nodoc:
		# If an active module has been selected and it's an exploit, get the
		# list of compatible payloads and display them
		if (active_module and active_module.exploit? == true)
			show_module_set("Compatible Payloads", active_module.compatible_payloads, regex)
		else
			show_module_set("Payloads", framework.payloads, regex)
		end
	end

	def show_auxiliary(regex = nil, minrank = nil) # :nodoc:
		show_module_set("Auxiliary", framework.auxiliary, regex, minrank)
	end

	def show_options(mod) # :nodoc:
		mod_opt = Serializer::ReadableText.dump_options(mod, '   ')
		print("\nModule options:\n\n#{mod_opt}\n") if (mod_opt and mod_opt.length > 0)

		# If it's an exploit and a payload is defined, create it and
		# display the payload's options
		if (mod.exploit? and mod.datastore['PAYLOAD'])
			p = framework.modules.create(mod.datastore['PAYLOAD'])

			if (!p)
				print_error("Invalid payload defined: #{mod.datastore['PAYLOAD']}\n")
				return
			end

			p.share_datastore(mod.datastore)

			if (p)
				p_opt = Serializer::ReadableText.dump_options(p, '   ')
				print("\nPayload options (#{mod.datastore['PAYLOAD']}):\n\n#{p_opt}\n") if (p_opt and p_opt.length > 0)
			end
		end

		# Print the selected target
		if (mod.exploit? and mod.target)
			mod_targ = Serializer::ReadableText.dump_exploit_target(mod, '   ')
			print("\nExploit target:\n\n#{mod_targ}\n") if (mod_targ and mod_targ.length > 0)
		end

		# Uncomment this line if u want target like msf2 format
		#print("\nTarget: #{mod.target.name}\n\n")
	end

	def show_global_options
		columns = [ 'Option', 'Current Setting', 'Description' ]
		tbl = Table.new(
			Table::Style::Default,
			'Header'  => 'Global Options:',
			'Prefix'  => "\n",
			'Postfix' => "\n",
			'Columns' => columns
			)
		[
			[ 'ConsoleLogging', framework.datastore['ConsoleLogging'] || '', 'Log all console input and output' ],
			[ 'LogLevel', framework.datastore['LogLevel'] || '', 'Verbosity of logs (default 0, max 3)' ],
			[ 'MinimumRank', framework.datastore['MinimumRank'] || '', 'The minimum rank of exploits that will run without explicit confirmation' ],
			[ 'SessionLogging', framework.datastore['SessionLogging'] || '', 'Log all input and output for sessions' ],
			[ 'TimestampOutput', framework.datastore['TimestampOutput'] || '', 'Prefix all console output with a timestamp' ],
		].each { |r| tbl << r }

		print(tbl.to_s)
	end

	def show_targets(mod) # :nodoc:
		mod_targs = Serializer::ReadableText.dump_exploit_targets(mod, '   ')
		print("\nExploit targets:\n\n#{mod_targs}\n") if (mod_targs and mod_targs.length > 0)
	end

	def show_actions(mod) # :nodoc:
		mod_actions = Serializer::ReadableText.dump_auxiliary_actions(mod, '   ')
		print("\nAuxiliary actions:\n\n#{mod_actions}\n") if (mod_actions and mod_actions.length > 0)
	end

	def show_advanced_options(mod) # :nodoc:
		mod_opt = Serializer::ReadableText.dump_advanced_options(mod, '   ')
		print("\nModule advanced options:\n\n#{mod_opt}\n") if (mod_opt and mod_opt.length > 0)

		# If it's an exploit and a payload is defined, create it and
		# display the payload's options
		if (mod.exploit? and mod.datastore['PAYLOAD'])
			p = framework.modules.create(mod.datastore['PAYLOAD'])

			if (!p)
				print_error("Invalid payload defined: #{mod.datastore['PAYLOAD']}\n")
				return
			end

			p.share_datastore(mod.datastore)

			if (p)
				p_opt = Serializer::ReadableText.dump_advanced_options(p, '   ')
				print("\nPayload advanced options (#{mod.datastore['PAYLOAD']}):\n\n#{p_opt}\n") if (p_opt and p_opt.length > 0)
			end
		end
	end

	def show_evasion_options(mod) # :nodoc:
		mod_opt = Serializer::ReadableText.dump_evasion_options(mod, '   ')
		print("\nModule evasion options:\n\n#{mod_opt}\n") if (mod_opt and mod_opt.length > 0)

		# If it's an exploit and a payload is defined, create it and
		# display the payload's options
		if (mod.exploit? and mod.datastore['PAYLOAD'])
			p = framework.modules.create(mod.datastore['PAYLOAD'])

			if (!p)
				print_error("Invalid payload defined: #{mod.datastore['PAYLOAD']}\n")
				return
			end

			p.share_datastore(mod.datastore)

			if (p)
				p_opt = Serializer::ReadableText.dump_evasion_options(p, '   ')
				print("\nPayload evasion options (#{mod.datastore['PAYLOAD']}):\n\n#{p_opt}\n") if (p_opt and p_opt.length > 0)
			end
		end
	end

	def show_plugins # :nodoc:
		tbl = generate_module_table("Plugins")

		framework.plugins.each { |plugin|
			tbl << [ plugin.name, plugin.desc ]
		}

		print(tbl.to_s)
	end

	def show_module_set(type, module_set, regex = nil, minrank = nil) # :nodoc:
		tbl = generate_module_table(type)

		module_set.sort.each { |refname, mod|
			o = nil

			begin
				o = mod.new
			rescue ::Exception
			end
			next if not o

			# handle a search string, search deep
			if(
				not regex or
				o.name.match(regex) or
				o.description.match(regex) or
				o.refname.match(regex) or
				o.references.map{|x| [x.ctx_id + '-' + x.ctx_val, x.to_s]}.join(' ').match(regex) or
				o.author.to_s.match(regex)
			)
				if (not minrank or minrank <= o.rank)
					tbl << [ refname, o.rank_to_s, o.name ]
				end
			end
		}

		print(tbl.to_s)
	end

	def generate_module_table(type) # :nodoc:
		Table.new(
			Table::Style::Default,
			'Header'  => type,
			'Prefix'  => "\n",
			'Postfix' => "\n",
			'Columns' => [ 'Name', 'Rank', 'Description' ]
			)
	end
end

end end end end

