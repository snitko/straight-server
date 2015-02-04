Straight server
===============
> A stand-alone Bitcoin payment gateway server
> Receives bitcoin payments directly into your wallet, holds no private keys

> Website: http://straight.mycelium.com

If you'd like to accept Bitcoin payments on your website automatically, but you're not
fond of services like Coinbase or Bitpay, which hold your bitcoins for you and require a ton
of AML/KYC info, you came to the right place.

Straight server is a software you install on your machine, which you can then talk to
via a RESTful API to create orders and generate payment addresses. Straight server will
issue callback requests to the specified URLs when the bitcoins arrive and store all the information
about the order in a DB.

While it is written in Ruby, I made special effort so that it would be easy to install and configure.
You can use Straight server with any application and website. You can even run your own payment
gateway which serves many online stores.

Straight uses BIP32 pubkeys so that you and only you control your private keys.
If you're not sure what a BIP32 address and HD wallets are, read this article:
http://bitcoinmagazine.com/8396/deterministic-wallets-advantages-flaw/

You might also be interested in a stateless [Straight](https://github.com/snitko/straight) library that is the base for Straight server.

Installation
------------
I currently only tested it on Unix machines.

1. Install RVM and Ruby 2.1 (see [RVM guide](http://rvm.io/rvm/install))

2. run `gem install straight-server`

3. start the server by running `straight-server`. This will generate a` ~/.straight` dir and put a `config.yml`
file in there, then shut down. You have to edit the file first to be able to run the server again.

4. In `config.yml`, under the `gateways/default` section, insert your BIP32 pubkey and a callback URL.
Everything may be left as is for now. To generate a BIP32 private/public keys, you can use one of the
wallets that support BIP32 (currently it's bitWallet for iOS) or go to http://bip32.org

5. Run the server again with `straight-server -p 9696`


Usage
-----
When the server is running, you can access it via http and use its RESTful API.
Below I assume it runs on localhost on port 9696.

**Creating a new order:**

    # creates a new order for 1 satoshi
    POST /gateways/1/orders?amount=1

the result of this request will be the following json:

    {"status":0,"amount":1,"address":"1NZov2nm6gRCGW6r4q1qHtxXurrWNpPr1q","tid":null,"id":1 }

Now you can obviously use that output to provide your user with the address and the expected
amount to be sent there. At this point, the server starts automatically tracking the order address
in a separate thread, so that when the money arrive, a callback will be issued to the url provided
in the `~/.straight/config.yml` file for the current gateway. This callback request will contain order info too.
Here's an example of a callback url request that could be made by Straight server when order status changes:

    GET http://mystore.com/payment-callback?order_id=1&amount=1&status=2&address=1NZov2nm6gRCGW6r4q1qHtxXurrWNpPr1q&tid=tid1&data=some+random+data

As you may have noticed, there's a parameter called `data`. It is a way for you to pass info back
to your app. It will have the same value as the `data` parameter you passed to the create order request:

    POST /gateways/1/orders?amount=1&data=some+random+data

You can specify amount in other currencies, as well as various BTC denominations.
It will be converted using the current exchange rate (see [Straight::ExchangeAdapter](https://github.com/snitko/straight/blob/master/lib/straight/exchange_rate_adapter.rb)) into satoshis:

    # creates a new order for 1 USD
    POST /gateways/1/orders?amount=1&currency=USD

    # creates an order for 0.00000001 BTC or 1 satoshi
    POST /gateways/1/orders?amount=1&btc_denomination=btc


**Checking the order manually**
You can check the status of the order manually with the following request:

    GET /gateways/1/orders/1

may return something like:

    {"status":2,"amount":1,"address":"1NZov2nm6gRCGW6r4q1qHtxXurrWNpPr1q","tid":"f0f9205e41bf1b79cb7634912e86bb840cedf8b1d108bd2faae1651ca79a5838","id":1 }

**Subscribing to the order using websockets**:
You can also subscribe to the order status changes using websockets at:

    /gateways/1/orders/1/websocket

It will send a message to the client upon the status change and close connection afterwards.

**Order expiration**
means that after a certain time has passed, it is no longer possible to pay for it. Each order holds
its creation time in `#created_at` field. In turn, each order's gateway has a field called
`#orders_expiration_period` (you can set it as an option in config file for each particular gateway or in the DB,
depending on what approach to storing gateways you use). After this time has passed, straight-server stops
checking whether new transactions appear on the order's bitcoin address and also changes order's status to 5 (expired).

Implications of restarting the server
-------------------------------------

If you shut the server down and then start it again, all unresolved orders (status < 2 and non-expired)
are automatically picked up and the server starts checking on them again until they expire. Please note
that you'd need to make sure your client side reconnects to the order's websocket again. This is because
on server shutdown, all websocket connections are closed, therefore, there's no way to automatically restore them.
It is thus client's responsibility to check when websocket is closed, then periodically try to connect to it again.

Client Example
--------------
I've implemented a small client example app written purely in Dart. It creates new orders,
tracks changes via websockets and displays status info upon status change. To see how it works,
download Dartium browser and navigate it to the `http://localhost:9696` while running the
Straight server in development mode (nothing special has to be done for that).

The code for this client app example can be found in [examples/client](https://github.com/snitko/straight-server/tree/master/examples/client).

Using many different gateways
------------------------------
When you have many online stores, you'd want to create a separate gateway for each one of them.
They would all be running within one Straight server.

The standard way to do this is to use `~/.straight/config.yml` file. Under the `gateways` section,
simply add a new gateway (come up with a nice name for it!) and set all the options you see were
used for the default one. Change them as you wish. Restart the server.

To create an order for the new gateway, simply send this request:

    POST /gateways/2/orders?amount=1&currency=USD

Notice that the gateway id has changed to 2. Gateway ids are assigned according to the order in
which they follow in the config file.

** Gateways from DB **
When you have too many gateways, it is unwise to keep them in the config file. In that case,
you can store gateway settings in the DB. To do that, change `~/.straight/config.yml` setting
'gateways_source: config` to `gateways_source: db`.

Then you should be able to use `straight-console` to manually create gateways to the DB. To do
that, you'd have to consult [Sequel documentation](http://sequel.jeremyevans.net/) because currently
there is no standard way to manage gateways through a web interface. In the future, it will be added.
In general, it shouldn't be difficult, and may look like this:

    $ straight-console

    > g = Gateway.new
    > gateway.pubkey                 = 'xpub1234'
    > gateway.confirmations_required = 0
    > gateway.order_class            = 'StraightServer::Order'
    > gateway.callback_url           = 'http://myapp.com/payment_callback'
    > gateway.save
    > exit

Using signatures
----------------
If you are running straight-server on a machine separate from your online stores, you
HAVE to make sure that when somebody accesses your RESTful API it is those stores only,
and not somebody else. For that purpose, you're gonna need signatures.

Go to your `~/.straight/config.yml` directory and set two options for each of your gateways:

    secret: 'a long string of random chars'
    check_signature: true

This will force gateways to check signatures when you try to create a new order. A signature is
a HMAC SHA256 hash of the secret and an order id. Because you need order id, it means you have
to actually provide it manually in the params. It can be any integer > 0, but it's better
that it is a consecutive integer, so keep track of order ids in your application. Obviously,
if an order with such an id already exists, the request will be rejected. A possible request
(assuming secret is the line mentioned above in the sample config) would look like this:

    POST /gateways/1/orders?amount=1&order_id=1&signature=aa14c26b2ae892a8719b0c2c57f162b967bfbfbdcc38d8883714a0680cf20467

An example of obtaining such signature in Ruby:

    require 'openssl'
    
    secret = 'a long string of random chars'
    OpenSSL::HMAC.digest('sha256', secret, "1").unpack("H*").first # "1" may be order_id here

Straight server will also sign the callback url request. However, since the signature may be
known to an attacker once it was used for creating a new order, we can no longer use it directly.
Thus, Straight server will use a double signature calculated like this:

    secret = 'a long string of random chars'
    h1 = OpenSSL::HMAC.digest('sha256', secret, "1").unpack("H*").first
    h2 = OpenSSL::HMAC.digest('sha256', secret, h1).unpack("H*").first

and then send the request to the callback url with that signature:

    GET http://mystore.com/payment-callback?order_id=1&amount=1&status=2&address=1NZov2nm6gRCGW6r4q1qHtxXurrWNpPr1q&tid=tid1&data=some+random+data?signature=aa14c26b2ae892a8719b0c2c57f162b967bfbfbdcc38d8883714a0680cf20467

It is now up to your application to calculate that signature, compare it and
make sure that only one such request is allowed (that is, if signature was used, it cannot be used again).

Querying the blockchain
-----------------------
Straight currently uses third-party services, such as Blokchain.info and Helloblock.io to track
addresses and fetch transaction info. This means, you don't need to install bitcoind and store
the whole blockchain on your server. If one service is down, it will automatically switch to another one. I will be adding more adapters in the future. It will also be possible to implement a cross check where if one service is lying about a transaction, I can check with another. In the future, I will add bitcoind support too for those who do not trust third-party services.

To sum it up, there is nothing in the architecture of this software that says you should rely on third party services to query the blockchain.

Running in production
---------------------
Running in production usually assumes running server as daemon with a pid. Straight server
uses [Goliath](https://github.com/postrank-labs/goliath) so you can look up various options there.
However, my recommendation is the following:

    straight-server -e production -p 9696 --daemonize --pid ~/.straight/straight.pid

Note that goliath server log file settings do not apply here. Straight has its own logging
system and the file is usually `~/.straight/straight.log`. You can set various loggin options
in `~/.straight/config.yml`. For production, you may want to set log level to WARN and also
turn on email notifications, so that when a FATAL errors occurs, an email is sent to you address
(emailing would most likely require *sendmail* to be installed).

I would also recommend you to use something like *monit* daemon to monitor a *straight-server* process.

Running in different environments
---------------------------------
Additionally, there is a `--config-dir` (short version is `-c`) option that allows you to set the
config directory for the server. It becomes quite convenient if you decide to run, for example, both
production and staging instances on one machine. I decided against having config file sections for each environment
as this would be more complicated and quite unnatural. Apart from different config files, one might argue you can have
a different set of addons and different versions of them in the `~/.straight/addons` dir. So it's better to keep them separate.

If you think of wrong examples out there, consider Rails: why would I want to have a database.yml file with both
development and production sections if I know for sure I'm only running this instance in production env?

So, with straight, you can simply create a separate config dir for each instance. For example, if I want to run
both production and staging on my server, I'd do this:

1. Create `~/.straight/production` and `~/.straight/staging` dirs
2. Run two instances like this:

       straight-server --config-dir=~/.straight/production 
       straight-server --config-dir=~/.straight/staging

It's worth saying that currently, there is no default settings for production, staging or development.
It is you who defines what a production or a staging environment is, by changing the config file. Those words
are only used as examples. You may call your environment whatever you like.

Requirements
------------
Ruby 2.1 or later.

Donations
---------
To go on with this project and make it truly awesome, I need more time. I can only buy free time with money, so any donation is highly appreciated. Please send bitcoins over to **1D3PknG4Lw1gFuJ9SYenA7pboF9gtXtdcD**

Credits
-------
Author: [Roman Snitko](http://romansnitko.com)

Licence: MIT (see the LICENCE file)
