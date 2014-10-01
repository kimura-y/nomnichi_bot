require "sinatra/base"
require "webrick/https"
require "json"

module NomnichiBot
  module Command
    class Server
      def initialize(crt_file, rsa_file, token, username, servername = "localhost", port = 443, debug = false)
        NomnichiBot::Server.run(crt_file, rsa_file, token, username, servername, port, debug)
      end
    end # class Server
  end # module Command

  class Responder
    def initialize(myname)
      @myname = myname
    end

    # token=xxxxxxxxxxxxxxxx
    # team_id=T0001
    # channel_id=C2147483705
    # channel_name=test
    # timestamp=1355517523.000005
    # user_id=U2147483697
    # user_name=Steve
    # text=googlebot: What is the air-speed velocity of an unladen swallow?
    # trigger_word=googlebot:
    def respond(params)
      return nil if params[:user_name] == @myname || params[:user_name] == "slackbot"

      username = if params[:user_name]
                   '@' + params[:user_name]
                 else
                   ''
                 end
      return {:username => @myname, :text => "#{username} Hi!"}.to_json
    end
  end # class Responder

  class Server < Sinatra::Base

    post "/" do
      unless params[:token] == token
        halt 403, "Forbidden"
      end
      content_type :json
      responder.respond(params)
    end

    ################################################################
    ## class methods

    def self.run(crt_file, rsa_file, token, username, servername = "localhost", port = 443, debug = false)
      @token     = token
      @responder = Responder.new(username)

      opt = ssl_option(*create_cert(crt_file, rsa_file, servername), port, debug)

      Rack::Handler::WEBrick.run self, opt do |server|
        shutdown_proc = ->( sig ){ server.shutdown() }
        [ :INT, :TERM ].each{|e| Signal.trap( e, &shutdown_proc ) }
      end
    end

    ################################################################
    ## class instance variables

    class << self
      attr_accessor :token, :responder
    end

    def token;     self.class.token;     end
    def responder; self.class.responder; end

    ################################################################
    # private_class_methods

    def self.create_cert(crt_file, rsa_file, servername = "localhost", overwrite = false)
      crt_path = File.expand_path(crt_file)
      rsa_path = File.expand_path(rsa_file)

      if File.exists?(crt_path) && File.exists?(rsa_path) && !overwrite
        return [File.open(crt_path).read, File.open(rsa_path).read]
      end

      crt, rsa = WEBrick::Utils.create_self_signed_cert(
                   1024,
                   [["CN", servername]],
                   'Generated by Ruby/OpenSSL')

      File.open(crt_path, "w") {|f| f.write(crt)}
      File.open(rsa_path, "w") {|f| f.write(rsa)}
      return [crt, rsa]
    end

    def self.ssl_option(crt, rsa, port = 443, debug = false)

      loglevel = debug ? WEBrick::Log::DEBUG : WEBrick::Log::INFO

      return {
        :Port            => port,
        :Logger          => WEBrick::Log.new($stderr, loglevel),
        :SSLEnable       => true,
        :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
        :SSLCertificate  => OpenSSL::X509::Certificate.new(crt),
        :SSLPrivateKey   => OpenSSL::PKey::RSA.new(rsa)
      }
    end

    private_class_method :create_cert, :ssl_option

  end # class Server
end # module NomnichiBot
