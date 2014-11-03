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
    # == Asset Compilation
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
    # == Asset Precompilation
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
    # When using the :compiled option, Roda will assume you already the precompiled
    # asset files that were created when you called +compile_assets+ already exist.
    #
    # == Plugin Options
    #
    # :add_suffix :: Whether to append a .css or .js extension to asset routes in non-compiled mode
    #                (default: false)
    # :compiled :: A hash mapping asset identifiers to the unique id for the compiled asset file,
    #              used when precompilng your assets before application startup
    # :compiled_css_dir :: Directory name in which to store the compiled css file,
    #                      inside :compiled_path (default: :css_dir)
    # :compiled_css_route :: route under :prefix for compiled css assets (default: :compiled_css_dir)
    # :compiled_js_dir :: Directory name in which to store the compiled javascript file,
    #                     inside :compiled_path (default: :js_dir)
    # :compiled_js_route :: route under :prefix for compiled javscript assets (default: :compiled_js_dir)
    # :compiled_name :: Compiled file name prefix (default: 'app')
    # :compiled_path:: Path inside public folder in which compiled files are stored (default: :prefix)
    # :concat_only :: whether to just concatenate instead of concatentating
    #                 and compressing files (default: false)
    # :css_dir :: Directory name containing your css source, inside :path (default: 'css')
    # :css_headers :: A hash of additional headers for your rendered css files
    # :css_route :: route under :prefix for css assets (default: :css_dir)
    # :dependencies :: A hash of dependencies for your asset files.  Keys should be paths to asset files,
    #                  values should be arrays of paths your asset files depends on.  This is used to
    #                  detect changes in your asset files.
    # :headers :: A hash of additional headers for both js and css rendered files
    # :prefix :: prefix for assets path in your URL/routes (default: 'assets')
    # :path :: Path to your asset source directory (default: 'assets')
    # :public :: Path to your public folder, in which compiled files are placed (default: 'public')
    # :js_dir :: Directory name containing your javascript source, inside :path (default: 'js')
    # :js_headers :: A hash of additional headers for your rendered javascript files
    # :js_route :: route under :prefix for javascript assets (default: :js_dir)
    module Assets
      DEFAULTS = {
        :compiled_name => 'app'.freeze,
        :js_dir        => 'js'.freeze,
        :css_dir       => 'css'.freeze,
        :path          => 'assets'.freeze,
        :prefix        => 'assets'.freeze,
        :public        => 'public'.freeze,
        :concat_only   => false,
        :compiled      => false,
        :add_suffix    => false
      }
      JS_END = "\"></script>".freeze
      CSS_END = "\" />".freeze
      SPACE = ' '.freeze
      DOT = '.'.freeze
      SLASH = '/'.freeze
      NEWLINE = "\n".freeze
      EMPTY_STRING = ''.freeze
      JS_SUFFIX = '.js'.freeze
      CSS_SUFFIX = '.css'.freeze

      def self.load_dependencies(app, _opts = {})
        app.plugin :render
        app.plugin :caching
      end

      def self.configure(app, opts = {})
        if app.assets_opts
          prev_opts = app.assets_opts[:orig_opts]
          orig_opts = app.assets_opts[:orig_opts].merge(opts)
          [:headers, :css_headers, :js_headers, :dependencies].each do |s|
            if prev_opts[s]
              if opts[s]
                orig_opts[s] = prev_opts[s].merge(opts[s])
              else
                orig_opts[s] = prev_opts[s].dup
              end
            end
          end
          app.opts[:assets] = orig_opts.dup
          app.opts[:assets][:orig_opts] = orig_opts
        else
          app.opts[:assets] = opts.dup
          app.opts[:assets][:orig_opts] = opts
        end
        opts = app.opts[:assets]

        # Combine multiple values into a path, ignoring trailing slashes
        j = lambda do |*v|
          opts.values_at(*v).
            reject{|s| s.to_s.empty?}.
            map{|s| s.chomp('/')}.
            join('/').freeze
        end

        # Same as j, but add a trailing slash if not empty
        sj = lambda do |*v|
          s = j.call(*v)
          s.empty? ? s : (s + '/').freeze
        end

        DEFAULTS.each do |k, v|
          opts[k] = v unless opts.has_key?(k)
        end
        [
         [:compiled_js_dir, :js_dir],
         [:compiled_css_dir, :css_dir],
         [:compiled_path, :prefix],
         [:js_route, :js_dir],
         [:css_route, :css_dir],
         [:compiled_js_route, :compiled_js_dir],
         [:compiled_css_route, :compiled_css_dir]
        ].each do |k, v|
          opts[k]  = opts[v] unless opts.has_key?(k)
        end
        [:css_headers, :js_headers, :dependencies].each do |s|
          opts[s] ||= {} 
        end

        if headers = opts[:headers]
          opts[:css_headers] = headers.merge(opts[:css_headers])
          opts[:js_headers]  = headers.merge(opts[:js_headers])
        end
        opts[:css_headers]['Content-Type'] ||= "text/css; charset=UTF-8".freeze
        opts[:js_headers]['Content-Type']  ||= "application/javascript; charset=UTF-8".freeze

        [:css_headers, :js_headers, :dependencies].each do |s|
          opts[s].freeze
        end
        [:headers, :css, :js].each do |s|
          opts[s].freeze if opts[s]
        end

        # Used for reading/writing files
        opts[:js_path]           = sj.call(:path, :js_dir)
        opts[:css_path]          = sj.call(:path, :css_dir)
        opts[:compiled_js_path]  = j.call(:public, :compiled_path, :compiled_js_dir, :compiled_name)
        opts[:compiled_css_path] = j.call(:public, :compiled_path, :compiled_css_dir, :compiled_name)

        # Used for URLs/routes
        opts[:js_prefix]           = sj.call(:prefix, :js_route)
        opts[:css_prefix]          = sj.call(:prefix, :css_route)
        opts[:compiled_js_prefix]  = j.call(:prefix, :compiled_js_route, :compiled_name)
        opts[:compiled_css_prefix] = j.call(:prefix, :compiled_css_route, :compiled_name)
        opts[:js_suffix]           = opts[:add_suffix] ? JS_SUFFIX : EMPTY_STRING
        opts[:css_suffix]          = opts[:add_suffix] ? CSS_SUFFIX : EMPTY_STRING

        opts.freeze
      end

      module ClassMethods
        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end

        def compile_assets(type=nil)
          unless assets_opts[:compiled]
            opts[:assets] = assets_opts.merge(:compiled => {})
          end

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
            compile_assets_files(files, type, dirs) unless files.empty?
          end
        end

        def compile_assets_files(files, type, dirs)
          dirs = nil if dirs && dirs.empty?
          o = assets_opts
          app = new

          content = files.map do |file|
            file = "#{dirs.join('/')}/#{file}" if dirs
            file = "#{o[:"#{type}_path"]}#{file}"
            app.read_asset_file(file, type)
          end.join

          unless o[:concat_only]
            content = compress_asset(content, type)
          end

          suffix = ".#{dirs.join('.')}" if dirs
          key = "#{type}#{suffix}"
          unique_id = o[:compiled][key] = asset_digest(content)
          path = "#{o[:"compiled_#{type}_path"]}#{suffix}.#{unique_id}.#{type}"
          File.open(path, 'wb'){|f| f.write(content)}
          nil
        end

        def compress_asset(content, type)
          require 'yuicompressor'
          content = YUICompressor.send("compress_#{type}", content, :munge => true)
        rescue LoadError, Errno::ENOENT
          # yuicompressor or java not available, just use concatenated, uncompressed output
          content
        end

        def asset_digest(content)
          require 'digest/sha1'
          Digest::SHA1.hexdigest(content)
        end
      end

      module InstanceMethods
        # This will ouput the files with the appropriate tags
        def assets(type, attrs = nil)
          o = self.class.assets_opts
          type, *dirs = type if type.is_a?(Array)
          stype = type.to_s

          attrs = if attrs
            ru = Rack::Utils
            attrs.map{|k,v| "#{k}=\"#{ru.escape_html(v.to_s)}\""}.join(SPACE)
          else
            EMPTY_STRING
          end

          if type == :js
            tag_start = "<script type=\"text/javascript\" #{attrs} src=\"/"
            tag_end = JS_END
          else
            tag_start = "<link rel=\"stylesheet\" #{attrs} href=\"/"
            tag_end = CSS_END
          end

          # Create a tag for each individual file
          if compiled = o[:compiled]
            if dirs && !dirs.empty?
              key = dirs.join(DOT)
              ckey = "#{stype}.#{key}"
              if ukey = compiled[ckey]
                "#{tag_start}#{o[:"compiled_#{stype}_prefix"]}.#{key}.#{ukey}.#{stype}#{tag_end}"
              end
            elsif ukey = compiled[stype]
              "#{tag_start}#{o[:"compiled_#{stype}_prefix"]}.#{ukey}.#{stype}#{tag_end}"
            end
          else
            asset_dir = o[type]
            if dirs && !dirs.empty?
              dirs.each{|f| asset_dir = asset_dir[f]}
              prefix = "#{dirs.join(SLASH)}/"
            end
            Array(asset_dir).map{|f| "#{tag_start}#{o[:"#{stype}_prefix"]}#{prefix}#{f}#{o[:"#{stype}_suffix"]}#{tag_end}"}.join(NEWLINE)
          end
        end

        def render_asset(file, type)
          o = self.class.assets_opts
          if o[:compiled]
            file = "#{o[:"compiled_#{type}_path"]}#{file}"
            check_asset_request(file, type, File.stat(file).mtime)
            File.read(file)
          else
            file = "#{o[:"#{type}_path"]}#{file}"
            check_asset_request(file, type, asset_last_modified(file))
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

        def asset_last_modified(file)
          if deps = self.class.assets_opts[:dependencies][file]
            ([file] + Array(deps)).map{|f| File.stat(f).mtime}.max
          else
            File.stat(file).mtime
          end
        end

        def check_asset_request(file, type, mtime)
          request.last_modified(mtime)
          response.headers.merge!(self.class.assets_opts[:"#{type}_headers"])
        end
      end

      module RequestClassMethods
        # The matcher for the assets route
        def assets_matchers
          @assets_matchers ||= [:css, :js].map do |t|
            [t.to_s.freeze, assets_regexp(t)].freeze if roda_class.assets_opts[t]
          end.compact.freeze
        end

        private

        def assets_regexp(type)
          o = roda_class.assets_opts
          if compiled = o[:compiled]
            assets = compiled.select{|k,_| k =~ /\A#{type}/}.map do |k, md|
              "#{k.sub(/\A#{type}/, '')}.#{md}.#{type}"
            end
            /#{o[:"compiled_#{type}_prefix"]}(#{Regexp.union(assets)})/
          else
            assets = unnest_assets_hash(o[type])
            /#{o[:"#{type}_prefix"]}(#{Regexp.union(assets)})#{o[:"#{type}_suffix"]}/
          end
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
