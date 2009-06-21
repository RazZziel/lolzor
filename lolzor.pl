#!/usr/bin/perl

use warnings;
use LWP::Simple;
use LWP::UserAgent;
use Crypt::SSLeay;
use HTTP::Cookies;
use Term::ReadKey;
use Getopt::Long qw(GetOptionsFromString);
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

$g = GREEN;
$m = RED;
$y = YELLOW;
$c = CYAN;
$r = RESET;

sub test {
    open(DURR,'fbDump.htm');
    $fff = join('',<DURR>);
    close(DURR);
    return $fff;
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
    my ($band_name, $band_tour, $band_form) = @_;

    my @names = $band_form =~ /name="([^"]+)"/sgi;
    my @values = $band_form =~ /value="([^"]+)"/sgi;

    my %postData;
    for($i = 0; $i < scalar(@names); $i++) {
        $postData{$names[$i]} = $values[$i];
    }

    $browser->post($bandbattle.'/battle/battle', \%postData, @header);
    $response = $browser->get($bandbattle, @header);

    scan_messages($response->content, $band_name, $band_tour);
}

sub find_weakest_band {
    my ($content) = @_;
    my @min = (0, 999, 0);
    @matches = $content =~ m#<tr>[^<]*
                             <td>([^<]+)</td>[^<]*
                             <td>[^<]+</td>[^<]*
                             <td>([^<]+)\ other\ bands</td>[^<]*
                             <td>[^<]*<form(.*?)</form>#xsgi;

    for ($count = 0; $count < scalar(@matches); $count+=3) {
        if ($matches[$count+1] < $min[1]) {
            $min[0] = $matches[$count];
            $min[1] = $matches[$count+1];
            $min[2] = $matches[$count+2];
        }
    }

    return @min;
}

sub scan_messages {
    my $content = shift;

    sub message {
        my ($content, $msg) = @_;
        for ($msg) {
            s/(won)/$g$1$r/;
            s/(lost)/$m$1$r/;
            s/(enough )([a-z]+)/$1$y$2$r/;
            s/(gained \$)([,0-9]+)( and )([0-9]+)( skill)/$1$g$2$r$3$g$4$r$5/;
        }
        print '[',
           ($content =~ m/You have ([0-9]+) experience points/i ? GREEN : BLUE),
           BOLD, BLUE, $content =~ m/Fame Level: ([0-9]+)/, RESET,
           ($content =~ m/The value was increased/i ? GREEN.'↑↑'.RESET : ''),
           '|',
           BOLD, BLUE, $content =~ m/Energy: ([0-9]+)/, RESET,
           '|',
           BOLD, BLUE, $content =~ m/Money: \$([,0-9]+)/, RESET,
           '] ',
           $msg, RESET, "\n";
    }

    if ($content =~ m/(You (played|practiced|could not) [^<]+)/i) {
        $bleh = $1;
        $bleh =~ s/could not played/could not play/; # FFFFFFFFFFFF.
        message( $content, $bleh );
    }

    if ($content =~ m/(You (won|lost|(do|can) not) [^<]+)/) {
        my $msg = $1;
        my ($money, $skill) = (0, 0);

        if ($content =~ m/You gained \$([0-9]+) and ([0-9]+) skill points/) {
            ($money, $skill) = ($1, $2);
        } elsif ($content =~ m/You lost \$([0-9]+)/) {
            ($money, $skill) = (-$1, 0);
        }

        my ($band_name, $band_tour) = @_;

        for ($msg) {
            s/ \([^)]+\)//;
            s/(against) (.*) (taking)/$1 $c$2 \($band_tour\)$r $3/;
        }

        message( $content, ($money ? "($money,$skill) " : '')."$msg" );
    }

    if (0 and $content =~ m/You have(?: earned)? ([0-9]+) experience points/i ) {
        for($i = 0; $i < $1; $i++) {
            $target = (
                'attack_up'
                #'defense_up'
                #'max_energy'
                #'max_health'
                #'max_stamina'
                );
            $browser->get($bandbattle.'/manager/increase/'.$target, @header); # turn into a post or some shit
            message( $content, $target.' ↑↑' );
            scan_messages($content);
        }
    }

    if ($content =~ m/The value was increased/i) {
        message( $content, '↑↑' );
    }
}

sub work {
    my ($url, $sleep_time, $function, $function_param) = @_;

    while (1) {
        # Clear shit before sending our command, so
        # it doesn't mess message parsing up.
        $response = $browser->get($bandbattle.'/index/clear', @header);
        scan_messages($response->content);

        do { $response = $browser->get($url, @header) } until $response->content !~ m/500 read failed/;
        scan_messages($response->content);

        $_[2]($response->content, $function_param);

        $cookie_jar->save();

        sleep $sleep_time*60;
    }
}


sub thr_attack {
    work( $bandbattle.'/battle',
          2,
          sub {
              $_[0] =~ m/Confidence: ([0-9]+)/;
              if ($1 > 20) {
                  attack( find_weakest_band($_[0]) );
              }
          },
          @_ );
}

sub thr_do {
    my ($action, $energy) = ($_[0][0], $_[0][1]);

    work( $bandbattle.'/user_items/do/'.$action,
          $energy*5/36,
          sub {},
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

our %user_items = (
    'street'   => [ 4,  10],
    'park'     => [11,  15],
    'bar'      => [12,  20],
    'casino'   => [13,  25],
    'opener'   => [14,  30],
    'ship'     => [30,  40],
    'opening'  => [31,  45],
    'big'      => [53,  50],
    'mtour'    => [54,  75],
    'red'      => [55,  75],
    'club88'   => [63, 100],
    'wtour'    => [ 6, 150],

    'practice' => [ 1,   5],
    'jam'      => [ 2,  15],
    'lesson'   => [ 3,  20],
    'plesson'  => [ 9,  30],
    'garage'   => [10,  40],
    'compose'  => [39, 100],
    'producer' => [40, 200]
    );

my $attack = 0;
my @actions = ();
my $options = "";

if ( @ARGV > 0 ) {
    $options = join(' ', @ARGV);
    open(DERP, '>lolzor.conf');
    print DERP $options;
    close(DERP);
} else {
    open(DURR,'lolzor.conf');
    $options = join(' ', <DURR>);
    close(DURR);
}

login();

GetOptionsFromString( $options,
                      'stats'  => sub { stats(); },
                      'attack' => \$attack,
                      'do=s'   => \@actions );

async { thr_attack(); } if ($attack);
async { thr_do($user_items{$_}) if exists $user_items{$_}; } foreach @actions;



$_->join() foreach threads->list(threads::all);
