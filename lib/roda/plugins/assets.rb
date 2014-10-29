class Roda
  module RodaPlugins
    # The assets plugin adds support for rendering your CSS and javascript
    # asset files using the render plugin in development, and compiling them
    # to a single, compressed file in production.
    #
    # When loading the plugin, use the :css and :js options
    # to set the source file(s) to use for CSS and javascript assets:
    #
    #   plugin :assets, :css => 'some_file', :js => 'some_file'
    #
    # By default, the plugin assumes coffeescript source for javascript files,
    # and SCSS source for CSS files.  You can override those choices using the
    # :css_engine and :js_engine options.
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
    # your front end and back end.  To do this you'd simply do:
    #
    #   plugin :assets, :css => {:frontend => 'some_frontend_file',
    #                            :backend => 'some_backend_file'}
    #
    # Then in your view code use an array argument in your call to assets:
    #
    #   <%= assets([:css, :frontend]) %>
    #
    # In production, you are generally going to want to compile your assets
    # into a single file, with you can do by calling compile_assets after
    # loading the plugin:
    #
    #   plugin :assets, :css => 'some_file', :js => 'some_file'
    #   compile_assets
    #
    # After calling compile_assets, calls to assets in your views will default
    # to a using a single link each to your CSS and javascript compiled asset
    # files.  By default the compiled files are written to the public folder,
    # so that they can be served by the webserver.
    #
    # You can provide options to the plugin method, or later by modifying
    # +assets_opts+.
    #
    # :js_folder :: Folder name containing your javascript (default: 'js')
    # :css_folder :: Folder name containing your stylesheets (default: 'css')
    # :path :: Path to your assets directory (default: 'assets')
    # :compiled_path :: Path to save your compiled files to (default: "public/:prefix")
    # :compiled_name :: Compiled file name (default: "app")
    # :prefix :: prefix for assets path, including trailing slash if not empty (default: 'assets/')
    # :css_engine :: default engine to use for css (default: 'scss')
    # :js_engine :: default engine to use for js (default: 'coffee')
    # :concat_only :: whether to just concatenate instead of concatentating
    #                 and compressing files (default: false)
    # :compiled :: whether to turn on using compiled files (default: false)
    # :headers :: Add additional headers to both js and css rendered files
    # :css_headers :: Add additional headers to your css rendered files
    # :js_headers :: Add additional headers to your js rendered files
    # :unique_ids :: A hash of types/folders to the unique id for the compiled asset file
    module Assets
      def self.load_dependencies(app, _opts)
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
        opts[:path]          ||= File.expand_path('assets', Dir.pwd)
        opts[:compiled_name] ||= 'app'
        opts[:prefix]        ||= 'assets/'
        opts[:compiled_path] ||= "public/#{opts[:prefix]}"
        opts[:css_engine]    ||= 'scss'
        opts[:js_engine]     ||= 'coffee'
        opts[:concat_only]     = false unless opts.has_key?(:concat_only)
        opts[:compiled]        = opts.has_key?(:unique_ids) unless opts.has_key?(:compiled)
        opts[:unique_ids]    ||= {} 

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
          if type == nil
            compile_assets(:css)
            compile_assets(:js)
          else
            files = assets_opts[type]

            case files
            when Hash
              files.each do |folder, f|
                compile_process_files(Array(f), type.to_s, folder.to_s)
              end
            when nil
              # No files for this asset type
            else
              compile_process_files(Array(files), type.to_s, type.to_s)
            end
          end

          assets_opts[:compiled] = true
          assets_opts[:unique_ids]
        end

        private

        def compile_process_files(files, type, folder)
          require 'digest/sha1'

          app = new
          content = files.map do |file|
            if type != folder && file !~ /\A\.\//
              file = "#{folder}/#{file}"
            end
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

          key = "#{type}#{".#{folder}" unless type == folder}"
          unique_id = assets_opts[:unique_ids][key] = Digest::SHA1.hexdigest(content)
          path = "#{assets_opts.values_at(:compiled_path, :"#{type}_folder", :compiled_name).join('/')}#{".#{folder}" unless type == folder}.#{unique_id}.#{type}"
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
              "#{tag_start}#{o[:compiled_name]}.#{key}.#{o[:unique_ids][stype]}#{tag_end}"
            else
              "#{tag_start}#{o[:compiled_name]}.#{o[:unique_ids][stype]}#{tag_end}"
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
          assets_opts = self.class.assets_opts

          # set the current engine
          engine = assets_opts[:"#{type}_engine"]

          # set the current folder
          folder = assets_opts[:"#{type}_folder"]

          # If it's not a parent directory append the full path
          if file !~ /\A\.\//
            file = "#{assets_opts[:path]}/#{folder}/#{file}"
          end

          if File.exist?("#{file}.#{engine}")
            # render via tilt
            render(:path => "#{file}.#{engine}")
          elsif File.exist?("#{file}.#{type}")
            # read file directly
            File.read("#{file}.#{type}")
          elsif file =~ /\.#{type}\z/
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
          assets = if o[:compiled]
            o[:unique_ids].select{|k| k =~ /\A#{type}/}.map do |k, md|
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
