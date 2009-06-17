#!/usr/bin/perl

use warnings;
use LWP::Simple;
use LWP::UserAgent;
use Crypt::SSLeay;
use HTTP::Cookies;
use Term::ReadKey;
use Term::ANSIColor;
use Term::ANSIColor qw(:constants);
use threads ( 'yield',
              'stack_size' => 64*4096,
              'exit' => 'threads_only',
              'stringify' );

my $bandbattle = 'http://apps.facebook.com/bandbattle';
my $browser;
my @header = ( 'Referer'    => 'http://www.facebook.com',
               'User-Agent' => 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2a1pre) Gecko/20090604 Minefield/3.6a1pre' );
$Term::ANSIColor::AUTORESET = 1;


sub test {
    open(DURR,'fbDump.htm');
    return join('',<DURR>);
}

sub damp {
    open(DERP, '>fbDump-'.time().'.htm');
    print DERP $_[0];
    close(DERP);
}

sub login {
    our $cookie_jar = HTTP::Cookies->new(file=>'fbCookies.dat',autosave=>1, ignore_discard=>1);
    $browser = LWP::UserAgent->new;
    $browser->cookie_jar($cookie_jar);

    unless (-e 'fbCookies.dat') {
        print "¯\\(°_o)/¯·oO(email) ";
        my $email = <STDIN>;
        print "¯\\(°_o)/¯·oO(pass)  ";
        ReadMode('noecho');
        my $password = <STDIN>;
        ReadMode('normal');

        chomp($email);
        chomp($password);

        my %postLoginData;
        $postLoginData{'email'}      = $email;
        $postLoginData{'pass'}       = $password;
        $postLoginData{'persistent'} = 1;
        $postLoginData{'login'}      = 'Login';

        # login
        $response = $browser->get('http://www.facebook.com/login.php', @header);
        $browser->post('https://login.facebook.com/login.php', \%postLoginData, @header);
    }

    $response = $browser->get($bandbattle, @header);

    if($response->content =~ /Sign up and use Battle of the Bands on Facebook/)
    {
        print "Login Failed...Quitting..\n";
        exit;
    }

    print "..and we are in!\n";
    $cookie_jar->save();
}



sub attack {
    @names = $_[2] =~ /name="([^"]+)"/sgi;
    @values = $_[2] =~ /value="([^"]+)"/sgi;

    my %postData;
    for($i = 0; $i < scalar(@names); $i++) {
        $postData{$names[$i]} = $values[$i];
    }

    $browser->post($bandbattle.'/battle/battle', \%postData, @header);
    my $response = $browser->get($bandbattle, @header);

    return unless $response->content =~ m/(You (won|lost|do not) (?:[^<]+))/;
    my $msg = $1;

    my ($money, $skill) = (0, 0);
    if ($response->content =~ m/You gained \$([0-9]+) and ([0-9]+) skill points/) {
        ($money, $skill) = ($1, $2);
    } elsif ($response->content =~ m/You lost \$([0-9]+)/) {
        ($money, $skill) = (-$1, 0);
    }

    damp($msg."\n--------------\n".$response->content) unless (length($msg) > 15);

    $g = GREEN;
    $m = RED;
    $y = YELLOW;
    $c = CYAN;
    $r = RESET;
    for ($_[0]) {
        s/\(/\\\(/;
        s/\)/\\\)/;
        s/\//\\\//;
    }
    for ($msg) {
        s/(won)/$g$1$r/;
        s/(lost)/$m$1$r/;
        s/(enough )(stamina)/$1$y$2$r/;
        s/($_[0])/$c$1 \($_[1]\)$r/;
    }

    print "($money,$skill) $msg", RESET, "\n";
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
        $browser->get($bandbattle.'/manager/increase/attack_up',@header);#ololo
        $response = $browser->get($_[0], @header);

        unless ($response->content =~ m/500 read failed/) {
            print '[',
              ($response->content =~ m/You have ([0-9]+) experience points/ ? GREEN : BLUE),
              BOLD, BLUE, $response->content =~ m/Fame Level: ([0-9]+)/, RESET,
              ($response->content =~ m/The value was increased/ ? GREEN.'↑↑'.RESET : ''),
              '|',
              BOLD, BLUE, $response->content =~ m/Energy: ([0-9]+)/, RESET,
              '|',
              BOLD, BLUE, $response->content =~ m/Money: \$([,0-9]+)/, RESET,
              '] ';

              $_[2]($response->content, $_[3]);
        }

        $cookie_jar->save();
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
          $_[1]*5/36,
          sub {
              $_[0] =~ s/could not played/could not play/; # FFFFFFFFFFFF.
              print $_[0] =~ m#<div style="font-size: 90%; font-weight: bold; margin-bottom: 3px;">(?:[^<]+?)</div>([^<]+?)</div>#si, "\n";
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
#async { thr_do(63, 100); }; #club88

#async { thr_do( 1,  5); }; #practice
#async { thr_do( 2, 15); }; #jam
#async { thr_do( 3, 20); }; #lesson
#async { thr_do( 9, 30); }; #pro lesson
#async { thr_do(10, 40); }; #garage jam
#async { thr_do(39,100); }; #compose
#async { thr_do(40,200); }; #producer

$_->join() foreach threads->list(threads::all);
#/bandbattle/manager/increase/attack_up
#/bandbattle/manager/increase/defense_up
#/bandbattle/manager/increase/max_energy
#/bandbattle/manager/increase/max_health
#/bandbattle/manager/increase/max_stamina

#<div class="flash"><div style="font-size: 90%; font-weight: bold; margin-bottom: 3px;">This amp goes up to 11.</div>The value was increased</div>
#<div class="flash">(...)You have 3 experience points, use them to increase your bands attack, defense, max stamina, or max energy.(...)</div>
