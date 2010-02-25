module Rex
module Script
class Base

	class OutputSink
		def print(msg); end
		def print_line(msg); end
		def print_status(msg); end
		def print_good(msg); end
		def print_error(msg); end
	end

	attr_accessor :client, :framework, :path, :error, :args
	attr_accessor :session, :sink

	def initialize(client, path)
		self.client    = client
		self.framework = client.framework
		self.path      = path
		self.sink      = OutputSink.new

		# Convenience aliases
		self.session   = self.client
	end

	def output
		client.user_output || self.sink
	end

	def completed
		raise Rex::Script::Completed
	end

	def run(*argset)
		args = argset.join(" ")
		self.args = args
		begin
			eval(::File.read(self.path, ::File.size(self.path)), binding )
		rescue ::Interrupt
		rescue ::Rex::Script::Completed
		rescue ::Exception => e
			self.error = e
			raise e
		end
	end

	def print(*args);         output.print(*args);          end
	def print_status(*args);  output.print_status(*args);   end
	def print_error(*args);   output.print_error(*args);    end
	def print_good(*args);    output.print_good(*args);     end
	def print_line(*args);    output.print_line(*args);     end

end
end
end
