require "tilt"
require 'open-uri'
class Roda
  module RodaPlugins
    module Assets
      def self.load_dependencies(app, opts={})
        app.plugin :render
      end

      def self.configure(app, opts={}, &block)
        if app.opts[:assets]
          app.opts[:assets].merge!(opts)
        else
          app.opts[:assets] = opts.dup
        end

        opts                = app.opts[:assets]
        opts[:css]        ||= []
        opts[:js]         ||= []
        opts[:js_folder]  ||= 'js'
        opts[:css_folder] ||= 'css'
        opts[:path]       ||= File.expand_path("assets", Dir.pwd)
        opts[:route]      ||= 'assets'
        opts[:css_engine] ||= 'scss'
        opts[:js_engine]  ||= 'coffee'
        opts[:concat]     ||= false
        opts[:compile]    ||= false
        opts[:headers]    ||= {}
        opts[:cache]        = app.thread_safe_cache if opts.fetch(:cache, true)

        yield opts if block
      end

      module ClassMethods
        # Copy the assets options into the subclass, duping
        # them as necessary to prevent changes in the subclass
        # affecting the parent class.
        def inherited(subclass)
          super
          opts         = subclass.opts[:assets] = assets_opts.dup
          opts[:cache] = thread_safe_cache if opts[:cache]
        end

        # Return the assets options for this class.
        def assets_opts
          opts[:assets]
        end
      end

      module InstanceMethods
        def assets_opts
          self.class.assets_opts
        end

        def assets type, options = {}
          attrs = options.map{|k,v| "#{k}=\"#{v}\""}
          tags  = []
          type  = [type] unless type.is_a? Array
          files = type.length == 1 \
                ? assets_opts[:"#{type[0]}"] \
                : assets_opts[:"#{type[0]}"][:"#{type[1]}"]

          files.each do |file|
            file.gsub!(/\./, '$2E')
            file = file.split('/')
            file[file.length - 1] = file.last.gsub(/\$2E/, '.')
            file = file.join '/'
            path = assets_opts[:route] + '/' + assets_opts[:"#{type[0]}_folder"]
            attr = type[0].to_s == 'js' ? 'src' : 'href'
            attrs.unshift "#{attr}=\"/#{path}/#{file}\""
            tags << send("#{type[0]}_assets_tag", attrs.join(' '))
          end

          tags.join "\n"
        end

        private

        # <link rel="stylesheet" href="theme.css">
        def css_assets_tag attrs
          "<link rel=\"stylesheet\" #{attrs} />"
        end

        # <script src="scriptfile.js"></script>
        def js_assets_tag attrs
          "<script type=\"text/javascript\" #{attrs}></script>"
        end

        def render_asset *args
          self.class.render_asset(*args)
        end
      end

      module RequestClassMethods
        def assets_opts
          roda_class.assets_opts
        end

        %w(css js).each do |type|
          define_method "#{type}_assets_path" do
            Regexp.new(
              assets_opts[:route] + '/' + assets_opts[:"#{type}_folder"] + '/(.*)(\.(css|js)|http.*)$'
            )
          end
        end
      end

      module RequestMethods
        def assets
          %w(css js).each do |type|
            on self.class.public_send "#{type}_assets_path" do |file, ext|
              file.gsub!(/(\$2E|%242E)/, '.')

              content_type = Rack::Mime.mime_type ".#{type}"

              response.headers.merge!({
                "Content-Type" => content_type + '; charset=UTF-8',
              }.merge(scope.assets_opts[:headers]))

              engine = scope.assets_opts[:"#{type}_engine"]

              if !file[/^\.\//] && !file[/^http/]
                path = scope.assets_opts[:path] + '/' + scope.assets_opts[:"#{type}_folder"] + "/#{file}"
              else
                path = file
              end

              if File.exists? "#{path}.#{engine}"
                scope.render path: "#{path}.#{engine}"
              elsif File.exists? path + ext
                File.read path + ext
              elsif ext[/^http/]
                open(ext).read
              elsif File.exists? path
                begin
                  scope.render path: path
                rescue
                  File.read path
                end
              end
            end
          end
        end
      end
    end

    register_plugin(:assets, Assets)
  end
end
