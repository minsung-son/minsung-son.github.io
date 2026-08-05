# Dev-server only: answer Chrome DevTools' origin-root workspace probe, which `jekyll serve`
# (mounted under baseurl) otherwise 404s on every page load. Nothing is added to the built site.
require "digest"
require "json"

module DevtoolsJson
  PATH = "/.well-known/appspecific/com.chrome.devtools.json"
  @mounted = false

  def self.mount(site)
    return if @mounted
    @mounted = true

    root = site.source
    md5  = Digest::MD5.hexdigest(root)
    uuid = "#{md5[0, 8]}-#{md5[8, 4]}-#{md5[12, 4]}-#{md5[16, 4]}-#{md5[20, 12]}"
    body = JSON.generate(workspace: { root: root, uuid: uuid })

    # The first build finishes before the WEBrick server exists — wait on the side; time out under `jekyll build`
    Thread.new do
      server = nil
      60.times do
        server = Jekyll::Commands::Serve.instance_variable_get(:@server)
        break if server
        sleep 0.25
      end
      if server
        server.mount_proc PATH do |_req, res|
          res["Content-Type"] = "application/json"
          res.body = body
        end
      end
    end
  end
end

Jekyll::Hooks.register :site, :post_write do |site|
  DevtoolsJson.mount(site)
end
