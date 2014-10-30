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
    #   plugin :assets, :css => {:frontend => 'some_frontend_file',
    #                            :backend => 'some_backend_file'}
    #
    # Then in your view code use an array argument in your call to assets:
    #
    #   <%= assets([:css, :frontend]) %>
    #
    # Hashes can also supporting nesting, though that should only be needed
    # in fairly large applications.
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
    # files.  By default the compiled files are written to the public folder,
    # so that they can be served by the webserver.
    #
    # :js_folder :: Folder name containing your javascript (default: 'js')
    # :css_folder :: Folder name containing your stylesheets (default: 'css')
    # :path :: Path to your assets directory (default: 'assets')
    # :compiled_path :: Path to save your compiled files to (default: "public/:prefix")
    # :compiled_name :: Compiled file name (default: "app")
    # :prefix :: prefix for assets path, including trailing slash if not empty (default: 'assets/')
    # :concat_only :: whether to just concatenate instead of concatentating
    #                 and compressing files (default: false)
    # :compiled :: A hash mapping asset identifiers to the unique id for the compiled asset file
    # :headers :: Add additional headers to both js and css rendered files
    # :css_headers :: Add additional headers to your css rendered files
    # :js_headers :: Add additional headers to your js rendered files
    module Assets
      def self.load_dependencies(app, _opts = {})
        app.plugin :render
      end

      def self.configure(app, opts = {})
        if app.assets_opts
          app.assets_opts.merge!(opts)
        else
          app.opts[:assets] = opts.dup
        end

        opts                   = app.opts[:assets]
        opts[:css]           ||= []
        opts[:js]            ||= []
        opts[:js_folder]     ||= 'js'
        opts[:css_folder]    ||= 'css'
        opts[:path]          ||= 'assets'
        opts[:compiled_name] ||= 'app'
        opts[:prefix]        ||= 'assets/'
        opts[:compiled_path] ||= "public/#{opts[:prefix]}"
        opts[:concat_only]     = false unless opts.has_key?(:concat_only)
        opts[:compiled]        = false unless opts.has_key?(:compiled)

        opts[:css_headers]   ||= {} 
        opts[:js_headers]    ||= {} 
        if headers = opts[:headers]
          opts[:css_headers] ||= headers.merge(opts[:css_headers])
          opts[:js_headers]  ||= headers.merge(opts[:js_headers])
        end
        opts[:css_headers]['Content-Type'] ||= "text/css; charset=UTF-8"
        opts[:js_headers]['Content-Type']  ||= "application/javascript; charset=UTF-8"

        if opts.fetch(:cache, true)
          opts[:cache] = app.thread_safe_cache
        end
      end

      # need to flattern js/css opts

      module ClassMethods
        # Copy the assets options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts               = subclass.opts[:assets] = assets_opts.dup
          opts[:css]         = opts[:css].dup
          opts[:js]          = opts[:js].dup
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
          when nil
            # No files for this asset type
          else
            compile_process_files(Array(files), type, dirs)
          end
        end

        def compile_process_files(files, type, dirs)
          dirs = nil if dirs && dirs.empty?
          require 'digest/sha1'

          app = new
          content = files.map do |file|
            file = "#{dirs.join('/')}/#{file}" if dirs
            app.read_asset_file(file, type)
          end.join

          unless assets_opts[:concat_only]
            begin
              require 'yuicompressor'
              content = YUICompressor.send("compress_#{type}", content, :munge => true)
            rescue LoadError
              # yuicompressor not available, just use concatenated, uncompressed output
            end
          end

          suffix = ".#{dirs.join('.')}" if dirs
          key = "#{type}#{suffix}"
          unique_id = assets_opts[:compiled][key] = Digest::SHA1.hexdigest(content)
          path = "#{assets_opts.values_at(:compiled_path, :"#{type}_folder", :compiled_name).join('/')}#{suffix}.#{unique_id}.#{type}"
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
            tag_start = "<script type=\"text/javascript\" #{attrs} src=\"/#{o[:prefix]}#{o[:"#{stype}_folder"]}/"
            tag_end = ".#{stype}\"></script>"
          else
            tag_start = "<link rel=\"stylesheet\" #{attrs} href=\"/#{o[:prefix]}#{o[:"#{stype}_folder"]}/"
            tag_end = ".#{stype}\" />"
          end

          # Create a tag for each individual file
          if o[:compiled]
            if dirs && !dirs.empty?
              key = dirs.join('.')
              stype = "#{stype}.#{key}"
              "#{tag_start}#{o[:compiled_name]}.#{key}.#{o[:compiled][stype]}#{tag_end}"
            else
              "#{tag_start}#{o[:compiled_name]}.#{o[:compiled][stype]}#{tag_end}"
            end
          else
            asset_folder = o[type]
            dirs.each{|f| asset_folder = asset_folder[f]} if dirs
            asset_folder.map{|f| "#{tag_start}#{f}#{tag_end}"}.join("\n")
          end
        end

        def render_asset(file, type)
          if self.class.assets_opts[:compiled]
            path = "#{self.class.assets_opts.values_at(:compiled_path, :"#{type}_folder").join('/')}/#{file}.#{type}"
            File.read(path)
          else
            read_asset_file file, type
          end
        end

        def read_asset_file(file, type)
          o = self.class.assets_opts
          folder = o[:"#{type}_folder"]
          file = "#{o[:path]}/#{folder}/#{file}"

          if file.end_with?(".#{type}")
            File.read(file)
          else
            render(:path => file)
          end
        end
      end

      module RequestClassMethods
        # The matcher for the assets route
        def assets_matcher
          @assets_matcher ||= [assets_regexp(:css), assets_regexp(:js)].freeze
        end

        private

        def assets_regexp(type)
          o = roda_class.assets_opts
          assets = if compiled = o[:compiled]
            compiled.select{|k| k =~ /\A#{type}/}.map do |k, md|
              "#{k.sub(/\A#{type}/, o[:compiled_name])}.#{md}"
            end
          else
            unnest_assets_hash(o[type])
          end
          /#{o[:prefix]}#{o[:"#{type}_folder"]}\/(#{Regexp.union(assets)})\.(#{type})/
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
          is self.class.assets_matcher do |file, type|
            response.headers.merge!(self.class.roda_class.assets_opts[:"#{type}_headers"])
            scope.render_asset(file, type)
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
