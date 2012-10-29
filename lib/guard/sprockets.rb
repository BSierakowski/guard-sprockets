require 'guard'
require 'guard/guard'

require 'sprockets'

module Guard
  class Sprockets < Guard

    attr_reader :asset_paths, :destination, :root_file, :sprockets

    def initialize(watchers = [], options = {})
      super(watchers, options)

      @options     = options
      @asset_paths = Array(@options[:asset_paths] || 'app/assets/javascripts')
      @destination = @options[:destination] || 'public/javascripts'
      if @options[:root_file]
        @root_file = Array(@options[:root_file])
      end

      @sprockets = ::Sprockets::Environment.new
      @asset_paths.each { |p| @sprockets.append_path(p) }

      if @options.delete(:minify)
        begin
          require 'uglifier'
          @sprockets.js_compressor = ::Uglifier.new
          UI.info 'Sprockets will compress output.'
        rescue LoadError => ex
          UI.error "minify: Uglifier cannot be loaded. No compression will be used.\nPlease include 'uglifier' in your Gemfile."
          UI.debug ex.message
        end
      end
    end

    def start
       UI.info 'Guard::Sprockets is ready and waiting for some file changes...'
       UI.debug "Guard::Sprockets.asset_paths = #{@asset_paths.inspect}" unless @asset_paths.empty?
       UI.debug "Guard::Sprockets.destination = #{@destination.inspect}"

       run_all
    end

    def run_all
      run_on_change(@root_file) if @root_file
    end

    def run_on_change(paths)
      paths = @root_file if @root_file

      success = true
      paths.each do |file|
        success &= sprocketize(file)
      end
      success
    end

    private

    def sprocketize(path)
      path = Pathname.new(path)

      @sprockets.append_path(path.dirname) unless @sprockets.paths.include?(path.dirname)

      output_filename = without_preprocessor_extension(path.basename.to_s)
      if File.extname(@destination)
        output_path = Pathname.new(@destination)
        UI.debug "Guard::Sprockets (destination was a file)"
      else
        output_path = Pathname.new(File.join(@destination, output_filename))
      end

      UI.debug "Guard::Sprockets.output_path = #{output_path}"
      UI.info "Sprockets will compile #{output_filename}"

      FileUtils.mkdir_p(output_path.parent) unless output_path.parent.exist?
      output_path.open('w') do |f|
        f.write @sprockets[output_filename]
      end

      UI.info "Sprockets compiled #{output_filename}"
      Notifier.notify "Sprockets compiled #{output_filename}"
    rescue Exception => ex
      UI.error "Sprockets failed compiling #{output_filename}"
      UI.error ex.message
      Notifier.notify "Sprockets #{output_filename}: #{ex.message}", :priority => 2, :image => :failed

      false
    end

    def without_preprocessor_extension(filename)
      filename.gsub(/^(.*\.(?:js|css))\.[^.]+$/, '\1')
    end

  end
end
