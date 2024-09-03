require "io"

module Config
    extend self
    def run(args : Array(String)) : String
        io = IO::Memory.new
        Process.run(args.join(" "), shell: true, output: io)
        io.to_s
    end
    
    def text(s : String, a : Array(String)) : String
        s
    end
    
    def date(s : String, a : Array(String)) : String
        outp = run(["date", a.join(" ")])
        s.gsub("%s", outp).rstrip
    end

    def echo(s : String, a : Array(String)) : String
    	outp = run(["echo", a.join(" ")])
	#puts a.join(" ")
	#puts outp
	s.gsub("%s", outp).rstrip
    end

    struct Field
        getter function : String, Array(String) -> String
        getter format : String
        getter arguments : Array(String)

        def initialize(@function, @format, @arguments); end
    end

    CONFIG = [
#                           FUNCTION                                 FORMAT                       ARGUMENTS        
        Field.new(->text(String, Array(String)),                     "Restart",                      [""]),
        #Field.new(->date(String, Array(String)),                     "%s",                          ["+%r"]),
	Field.new(->echo(String, Array(String)),                     "%s",                           ["\"$(date +%a) $(date +%b) $(date +%d) | $(date +%r)\""]),
    ]
end
