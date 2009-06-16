#!/usr/bin/perl

#use strict;
use warnings;
use LWP::Simple;
use LWP::UserAgent;
use Crypt::SSLeay;
use HTTP::Cookies;
use Term::ReadKey;
use threads ('yield',
             'stack_size' => 64*4096,
             'exit' => 'threads_only',
             'stringify');

my $email; #stores our mail
my $password; #stores our password
my $user_agent = 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2a1pre) Gecko/20090604 Minefield/3.6a1pre';
my $bandbattle = "http://apps.facebook.com/bandbattle";
our $browser;
our @header = ('Referer'=>'http://www.facebook.com', 'User-Agent'=>$user_agent);


sub test {
    open(DURR,"fbDump.htm");
    return join("",<DURR>);
}

sub damp {
    open(DERP, '>fbDump.htm');
    print DERP $_[0];
    close(DERP);
}



sub login {
    print "¯\\(°_o)/¯·oO(email) ";
    $email = <STDIN>;
    print "¯\\(°_o)/¯·oO(pass)  ";
    ReadMode('noecho');
    $password = <STDIN>;
    ReadMode('normal');

    chomp($email);
    chomp($password);

    my %postLoginData; #necessary post data for login
    $postLoginData{'email'}=$email;
    $postLoginData{'pass'}=$password;
    $postLoginData{'persistent'}=1;
    $postLoginData{'login'}='Login';

    our $response; #holds the response the HTTP requests

    our $cookie_jar = HTTP::Cookies->new(file=>'fbCookies.dat',autosave=>1, ignore_discard=>1);

    $browser = LWP::UserAgent->new; #init browser
    $browser->cookie_jar($cookie_jar);

    $response = $browser->get('http://www.facebook.com/login.php',@header);

    #here we actually login!
    $response = $browser->post('https://login.facebook.com/login.php',\%postLoginData,@header);

    #was login successful?
    if($response->content =~ /Incorrect Email/)
    {
        print "Login Failed...Quitting..\n";
        exit;
    }

    print "..and we are in!\n";
}



sub attack {
    @names = $_[2] =~ m#name="([^"]+)"#sgi;
    @values = $_[2] =~ m#value="([^"]+)"#sgi;

    my %postData;
    for($i = 0; $i < scalar(@names); $i++) {
        $postData{$names[$i]} = $values[$i];
    }

    $response = $browser->post($bandbattle.'/battle/battle',\%postData,@header);
    $response = $browser->get($bandbattle,@header);

    #damp($response->content);

    print '['.$_[0].' ('.$_[1].')] ', $response->content =~ m#<span style="color: (?:\#253a10|rgb\(91,\ 24,\ 38\)); font-weight: bold;">([^<]+)</span>#i, "\n";
}

sub find_weakest_band {
    my @min = (0, 999, "");
    @matches = $_[0] =~ m#<tr>(?:[^<]*)
                        <td>([^<]+)</td>(?:[^<]*)
                        <td>(?:[^<]+)</td>(?:[^<]*)
                        <td>([^<]+)\ other\ bands</td>(?:[^<]*)
                        <td>(?:[^<]*)<form(.*?)</form>#xsgi;

    for ($count = 0; $count < scalar(@matches); $count+=3) {
        if ($matches[$count+1] < $min[1]) {
            $min[0] = $matches[$count];
            $min[1] = $matches[$count+1];
            $min[2] = $matches[$count+2];
        }
    }

    return @min;
}

sub work {
    while (1) {
        $response = $browser->get($_[0],@header);

        $_[2]($response->content, $_[3]);

        $browser->get($bandbattle.'/manager/increase/attack_up',@header);#ololo
        sleep $_[1]*60;
    }
}


sub thr_attack {
    work( $bandbattle.'/battle',
          2,
          sub {
              attack( find_weakest_band($_[0]) );
          },
          @_ );
}

sub thr_do {
    work( $bandbattle.'/user_items/do/'.$_[0],
          $_[1]*5/27,
          sub {
              #damp($_[0]);
              print '['.$_[1].'] ', $_[0] =~ m#<div style="font-size: 90%; font-weight: bold; margin-bottom: 3px;">(?:[^<]+?)</div>([^<]+?)</div>#si, "\n";
          },
          @_ );
}

sub stats() {
    sub stats_promote() {
        print "Promote\n";
        $response = $browser->get( $bandbattle.'/promote', @header );
        @name = $response->content =~ m#<div style="font-size: 130%;">([^<]+)</div>#ig;
        @price = $response->content =~ m#Price: \$([,0-9]+)#ig;
        @mph = $response->content =~ m#Money per hour: \$([,0-9]+)#ig;
        printf "\t %-20s %15s↓↓\n", '', 'price/mph';
        for($i = 0; $i < scalar(@price); $i++) {
            $price[$i] =~ s/,//g;
            $mph[$i] =~ s/,//g;
            printf "\t %-20s %15.f\n", $name[$i], $price[$i]/$mph[$i];
        }
    }
    sub stats_travel() {
        print "Travel\n";
        $response = $browser->get( $bandbattle.'/travel_items', @header );
        @name = $response->content =~ m#<div style="font-size: 130%;">([^<]+)</div>#ig;
        @price = $response->content =~ m#Price: \$([,0-9]+)#ig;
        @mph = $response->content =~ m#Money per hour: \$([,0-9]+)#ig;
        @energy = $response->content =~ m#Energy every 5 minutes: ([0-9]+)#ig;
        printf "\t %-20s %15s↓↓ %13s↓↓\n", '', 'price/energy', 'mph/energy';
        for($i = 0; $i < scalar(@price); $i++) {
            $price[$i] =~ s/,//g;
            $mph[$i] =~ s/,//g;
            printf "\t %-20s %15.f %15.f\n", $name[$i], $price[$i]/$energy[$i], $mph[$i]/$energy[$i];
        }
    }

    stats_promote();
    stats_travel();
    exit;
}


login();

if ( @ARGV > 0 ) {
    GetOptions( 'stats' => stats() );
}

async { thr_attack(); };

#async { thr_do( 4, 10); }; #street
#async { thr_do(11, 15); }; #park
#async { thr_do(12, 20); }; #bar
#async { thr_do(13, 25); }; #casino
#async { thr_do(14, 30); }; #opener
#async { thr_do(30, 40); }; #ship
#async { thr_do(31, 45); }; #opening
#async { thr_do(53, 50); }; #big
#async { thr_do(54, 75); }; #tour
async { thr_do(55, 75); }; #red

#async { thr_do( 1,  5); }; #practice
#async { thr_do( 2, 15); }; #jam
#async { thr_do( 3, 20); }; #lesson
#async { thr_do( 9, 30); }; #pro lesson
#async { thr_do(10, 40); }; #garage jam
#async { thr_do(39,100); }; #compose
#async { thr_do(40,200); }; #producer

$_->join() foreach threads->list(threads::running);
#/bandbattle/manager/increase/attack_up
#/bandbattle/manager/increase/defense_up
#/bandbattle/manager/increase/max_energy
#/bandbattle/manager/increase/max_health
#/bandbattle/manager/increase/max_stamina
#<div class="flash"><div style="font-size: 90%; font-weight: bold; margin-bottom: 3px;">This amp goes up to 11.</div>The value was increased</div>
#<div class="flash">(...)You have 3 experience points, use them to increase your bands attack, defense, max stamina, or max energy.(...)</div>
