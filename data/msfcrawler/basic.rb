require 'rubygems'
require 'pathname'
require 'hpricot'
require 'uri'

class CrawlerSimple < BaseParser

	def parse(request,result)
		
		if !result['Content-Type'].include? "text/html"
			return
		end
		
		doc = Hpricot(result.body.to_s)
		doc.search('a').each do |link|
		
		hr = link.attributes['href']
		
		if hr and !hr.match(/^(\#|javascript\:)/) 
			begin
				uri = URI.parse(hr)
			
				tssl = false
				if uri.scheme == "https"
					tssl = true
				else
					tssl = false
				end

				if !uri.host or uri.host == nil
					thost = request['rhost']
					tssl = self.targetssl	
				else
					thost = uri.host	
				end

				if !uri.port or uri.port == nil
					tport = request['rport']
				else
					tport = uri.port
				end

				if !uri.path or uri.path == nil
					tpath = "/"
				else
					tpath = uri.path
				end
				
				
				
				newp = Pathname.new(tpath)
				oldp = Pathname.new(request['uri'])
				if !newp.absolute?
					if oldp.to_s[-1,1] == '/'
						newp = oldp+newp
					else
						if !newp.to_s.empty?
							newp = File.join(oldp.dirname,newp)
						end
					end		
				end

				hreq = {
					'rhost'		=> thost,
					'rport'		=> tport,
					'uri'  		=> newp.to_s,
					'method'   	=> 'GET',
					'ctype'		=> 'text/plain',
					'ssl'		=> tssl,
					'query'		=> uri.query,
					'data'		=> nil
					
				}

				insertnewpath(hreq)
					
			rescue URI::InvalidURIError
				#puts "Parse error"
				#puts "Error: #{link[0]}"
			end
		end
		end
	end 
end

