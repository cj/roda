class Roda
  module RodaPlugins
    # The assets plugin adds support for rendering your CSS and javascript
    # asset files using the render plugin in development, and compiling them
    # to a single, compressed file in production.
    #
    # When loading the plugin, use the :css and :js options
    # to set the source file(s) to use for CSS and javascript assets:
    #
    #   plugin :assets, :css => 'some_file.scss', :js => 'some_file.coffee'
    #
    # In your routes, call the r.assets method to add a route to your assets:
    #
    #   route do |r|
    #     r.assets
    #   end
    #
    # In your layout view, use the assets method to add links to your CSS and
    # javascript files assets:
    #
    #   <%= assets(:css) %>
    #   <%= assets(:js) %>
    #
    # You can add attributes to the tags by using options:
    #
    #   <%= assets(:css, :media => 'print') %>
    #
    # Assets also supports groups incase you have different css/js files for
    # your front end and back end.  To do this you pass a hash for the :css
    # and :js options:
    #
    #   plugin :assets, :css => {:frontend => 'some_frontend_file.scss',
    #                            :backend => 'some_backend_file.scss'}
    #
    # Then in your view code use an array argument in your call to assets:
    #
    #   <%= assets([:css, :frontend]) %>
    #
    # Hashes can also supporting nesting, though that should only be needed
    # in fairly large applications.
    #
    # ## Asset Compilation
    #
    # In production, you are generally going to want to compile your assets
    # into a single file, with you can do by calling compile_assets after
    # loading the plugin:
    #
    #   plugin :assets, :css => 'some_file.scss', :js => 'some_file.coffee'
    #   compile_assets
    #
    # After calling compile_assets, calls to assets in your views will default
    # to a using a single link each to your CSS and javascript compiled asset
    # files.  By default the compiled files are written to the public directory,
    # so that they can be served by the webserver.
    #
    # ## Asset Precompilation
    #
    # If you want to precompile your assets, so they do not need to be compiled
    # every time you boot the application, you can take the return value of
    # +compile_assets+, and use it as the value of the :compiled option when
    # loading the plugin.
    #
    # For example, let's say you want to store the compilation metadata in a JSON file.
    # You would load your application and call +compile_assets+, saving the result as JSON:
    #
    #   require 'json'
    #   File.write('compiled_assets.json', compile_assets.to_json)
    #
    # Then have your application load the compilation metadata from the JSON file when
    # booting:
    #
    #   require 'json'
    #   plugin :assets, :compiled=>JSON.parse(File.read('compiled_assets.json'))
    #
    # :prefix :: prefix for assets path in your URL/routes (default: 'assets')
    # :path :: Path to your asset source directory (default: 'assets')
    # :public :: Path to your public folder, in which compiled files are placed (default: 'public')
    # :compiled_prefix :: Path inside public folder in which compiled files are stored (default: :prefix)
    # :compiled_path :: Path to save your compiled files to (default: :public/:compiled_prefix)
    # :compiled_name :: Compiled file name prefix (default: 'app')
    # :css_dir :: Directory name containing your css source, inside :path (default: 'css')
    # :js_dir :: Directory name containing your javascript source, inside :path (default: 'js')
    # :compiled_css_dir :: Directory name in which to store the compiled css file,
    #                      inside :compiled_path (default: :css_dir)
    # :compiled_js_dir :: Directory name in which to store the compiled javascript file,
    #                     inside :compiled_path (default: :js_dir)
    # :concat_only :: whether to just concatenate instead of concatentating
    #                 and compressing files (default: false)
    # :compiled :: A hash mapping asset identifiers to the unique id for the compiled asset file,
    #              used when precompilng your assets before application startup
    # :headers :: A hash of additional headers for both js and css rendered files
    # :css_headers :: A hash of additional headers for your rendered css files
    # :js_headers :: A hash of additional headers for your rendered javascript files
    module Assets
      def self.load_dependencies(app, _opts = {})
        app.plugin :render
        app.plugin :caching
      end

      def self.configure(app, opts = {})
        if app.assets_opts
          app.assets_opts.merge!(opts)
        else
          app.opts[:assets] = opts.dup
        end
        opts = app.opts[:assets]

        # Combine multiple values into a path, ignoring trailing slashes
        j = lambda do |*v|
          opts.values_at(*v).
            reject{|s| s.to_s.empty?}.
            map{|s| s.chomp('/')}.
            join('/')
        end

        # Same as j, but add a trailing slash if not empty
        sj = lambda do |*v|
          s = j.call(*v)
          s << '/' unless s.empty?
          s
        end

        opts[:compiled_name] ||= 'app'
        opts[:css_headers]   ||= {} 
        opts[:js_headers]    ||= {} 

        opts[:js_dir]           = 'js' unless opts.has_key?(:js_dir)
        opts[:css_dir]          = 'css' unless opts.has_key?(:css_dir)
        opts[:compiled_js_dir]  = opts[:js_dir] unless opts.has_key?(:compiled_js_dir)
        opts[:compiled_css_dir] = opts[:css_dir] unless opts.has_key?(:compiled_css_dir)

        opts[:path]   = 'assets' unless opts.has_key?(:path)
        opts[:prefix] = 'assets' unless opts.has_key?(:prefix)
        opts[:public] = 'public' unless opts.has_key?(:public)

        opts[:compiled_prefix] = opts[:prefix] unless opts.has_key?(:compiled_prefix)
        opts[:compiled_path]   = sj.call(:public, :compiled_prefix) unless opts.has_key?(:compiled_path)
        opts[:concat_only]     = false unless opts.has_key?(:concat_only)
        opts[:compiled]        = false unless opts.has_key?(:compiled)

        if headers = opts[:headers]
          opts[:css_headers] = headers.merge(opts[:css_headers])
          opts[:js_headers]  = headers.merge(opts[:js_headers])
        end
        opts[:css_headers]['Content-Type'] ||= "text/css; charset=UTF-8"
        opts[:js_headers]['Content-Type']  ||= "application/javascript; charset=UTF-8"

        # Used for reading/writing files
        opts[:js_path]           = sj.call(:path, :compiled_js_dir)
        opts[:css_path]          = sj.call(:path, :compiled_css_dir)
        opts[:compiled_js_path]  = j.call(:compiled_path, :compiled_js_dir, :compiled_name)
        opts[:compiled_css_path] = j.call(:compiled_path, :compiled_css_dir, :compiled_name)

        # Used for URLs/routes
        opts[:js_prefix]           = sj.call(:prefix, :compiled_js_dir)
        opts[:css_prefix]          = sj.call(:prefix, :compiled_css_dir)
        opts[:compiled_js_prefix]  = j.call(:prefix, :compiled_js_dir, :compiled_name)
        opts[:compiled_css_prefix] = j.call(:prefix, :compiled_css_dir, :compiled_name)

        if opts.fetch(:cache, true)
          opts[:cache] = app.thread_safe_cache
        end
      end

      module ClassMethods
        # Copy the assets options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts               = subclass.opts[:assets] = assets_opts.dup
          opts[:css]         = opts[:css].dup if opts[:css] 
          opts[:js]          = opts[:js].dup if opts[:js]
          opts[:css_headers] = opts[:css_headers].dup
          opts[:js_headers]  = opts[:js_headers].dup
          opts[:cache] = thread_safe_cache if opts[:cache]
        end

        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end

        def compile_assets(type=nil)
          assets_opts[:compiled] ||= {}

          if type == nil
            _compile_assets(:css)
            _compile_assets(:js)
          else
            _compile_assets(type)
          end

          assets_opts[:compiled]
        end

        private

        def _compile_assets(type)
          type, *dirs = type if type.is_a?(Array)
          dirs ||= []
          files = assets_opts[type]
          dirs.each{|d| files = files[d]}

          case files
          when Hash
            files.each_key{|dir| _compile_assets([type] + dirs + [dir])}
          else
            files = Array(files)
            compile_process_files(files, type, dirs) unless files.empty?
          end
        end

        def compile_process_files(files, type, dirs)
          dirs = nil if dirs && dirs.empty?
          require 'digest/sha1'

          o = assets_opts
          app = new
          content = files.map do |file|
            file = "#{dirs.join('/')}/#{file}" if dirs
            file = "#{o[:"#{type}_path"]}#{file}"
            app.read_asset_file(file, type)
          end.join

          unless o[:concat_only]
            begin
              require 'yuicompressor'
              content = YUICompressor.send("compress_#{type}", content, :munge => true)
            rescue LoadError
              # yuicompressor not available, just use concatenated, uncompressed output
            end
          end

          suffix = ".#{dirs.join('.')}" if dirs
          key = "#{type}#{suffix}"
          unique_id = o[:compiled][key] = Digest::SHA1.hexdigest(content)
          path = "#{o[:"compiled_#{type}_path"]}#{suffix}.#{unique_id}.#{type}"
          File.open(path, 'wb'){|f| f.write(content)}
          nil
        end
      end

      module InstanceMethods
        # This will ouput the files with the appropriate tags
        def assets(type, attrs = {})
          o = self.class.assets_opts
          attrs = (attrs.map{|k,v| "#{k}=\"#{v}\""}.join(' ') unless attrs.empty?)
          type, *dirs = type if type.is_a?(Array)
          stype = type.to_s

          if type == :js
            tag_start = "<script type=\"text/javascript\" #{attrs} src=\"/"
            tag_end = "\"></script>"
          else
            tag_start = "<link rel=\"stylesheet\" #{attrs} href=\"/"
            tag_end = "\" />"
          end

          # Create a tag for each individual file
          if o[:compiled]
            if dirs && !dirs.empty?
              key = dirs.join('.')
              ckey = "#{stype}.#{key}"
              "#{tag_start}#{o[:"compiled_#{stype}_prefix"]}.#{key}.#{o[:compiled][ckey]}.#{stype}#{tag_end}"
            else
              "#{tag_start}#{o[:"compiled_#{stype}_prefix"]}.#{o[:compiled][stype]}.#{stype}#{tag_end}"
            end
          else
            asset_dir = o[type]
            if dirs && !dirs.empty?
              dirs.each{|f| asset_dir = asset_dir[f]}
              prefix = "#{dirs.join('/')}/"
            end
            Array(asset_dir).map{|f| "#{tag_start}#{o[:"#{stype}_prefix"]}#{prefix}#{f}#{tag_end}"}.join("\n")
          end
        end

        def render_asset(file, type)
          o = self.class.assets_opts
          if o[:compiled]
            file = "#{o[:"compiled_#{type}_path"]}#{file}"
            check_asset_request(file, type)
            File.read(file)
          else
            file = "#{o[:"#{type}_path"]}#{file}"
            check_asset_request(file, type)
            read_asset_file(file, type)
          end
        end

        def read_asset_file(file, type)
          if file.end_with?(".#{type}")
            File.read(file)
          else
            render(:path => file)
          end
        end

        private

        def check_asset_request(file, type)
          request.last_modified(File.stat(file).mtime)
          response.headers.merge!(self.class.assets_opts[:"#{type}_headers"])
        end
      end

      module RequestClassMethods
        # The matcher for the assets route
        def assets_matchers
          @assets_matchers ||= [['css'.freeze, assets_regexp(:css)].freeze, ['js'.freeze, assets_regexp(:js)].freeze].freeze
        end

        private

        def assets_regexp(type)
          o = roda_class.assets_opts
          if compiled = o[:compiled]
            key = :"compiled_#{type}_prefix"
            assets = compiled.select{|k| k =~ /\A#{type}/}.map do |k, md|
              "#{k.sub(/\A#{type}/, '')}.#{md}.#{type}"
            end
          else
            key = :"#{type}_prefix"
            assets = unnest_assets_hash(o[type])
          end
          /#{o[key]}(#{Regexp.union(assets)})/
        end

        def unnest_assets_hash(h)
          case h
          when Hash
            h.map{|k,v| unnest_assets_hash(v).map{|x| "#{k}/#{x}"}}.flatten(1)
          else
            Array(h)
          end
        end
      end

      module RequestMethods
        # Handles requests for assets
        def assets
          if is_get?
            self.class.assets_matchers.each do |type, matcher|
              is matcher do |file|
                scope.render_asset(file, type)
              end
            end
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
