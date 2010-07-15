module Gem
  (class << self; self; end).class_eval do
    def default_attributes
      %w(name version date files executables)
    end
    
    def set_root(root)
      @root = File.expand_path(root)
      @name = File.basename(@root)
      @conf ||= YAML.load File.read("#{@root}/gem.yml")
      @attributes ||= (default_attributes + @conf.keys.map(&:to_s)).uniq
    end
    
    # attr_reader :root, :conf, :attributes, 
    attr_reader :name

    def attribute(name)
      if @conf.key?(name) && !%w(dependencies).include?(name)
        @conf[name]
      else
        self.send(name)
      end
    end

    #
    # create a new Gem::Specification object for this gem.
    def spec(root)
      self.set_root root
    
      Gem::Specification.new do |s|
        @attributes.each do |attr|
          v = attribute(attr)
          next if v.nil?
          
          log attr, v
          
          s.send attr + "=", v
        end
        
        %w(pre_uninstall post_install).each do |hook|
          next unless File.exists?("#{root}/hooks/#{hook}.rb")
          log hook, "yes"
          Gem.send(hook) {
            load "hooks/#{hook}.rb"
          }
        end
      end
    end
    
    def log(attr, v)
      v = case attr
      when "files" then "#{v.length} files"
      else              v.inspect
      end
      
      STDERR.puts "#{"%20s" % attr}:\t#{v}"
    end
    
    def dependencies
      return nil unless @conf["dependencies"]

      @conf["dependencies"].map do |d|
        Gem::Dependency.new d, ">= 0"
      end
    end
    
    def head(file)
      File.open(file) do |f|
        f.readline
      end
    end
    
    def executables
      r = Dir.glob("#{@root}/bin/**/*").map do |file|
        next unless head(file) =~ /^#!/
        file[@root.length + 5 .. -1]
      end.compact
      
      return nil if r.empty?
      r
    end

    #
    # get files from git
    def files
      r = `git ls-files`.split("\n")
    end

    #
    # return the date
    def date
      Date.today.to_s
    end
  end
end
