use 5.010;
use strict;
use warnings;
use WWW::Mechanize;
use Coro;
use Coro::Timer;
use Encode;
use Text::MeCab;
use URI;
use Web::Query;
use FurlX::Coro;

######################Read Words in Neologd Vocabulary#######################
my %allWords = ();
my $dir = "/home/angeltop1/DLResearch/LINEInternReport/mecab-ipadic-neologd/decompressed_seed/all_neolodg_word_include_mecab.txt";
#my $dir = "/home/angeltop1/DLResearch/LINEInternReport/mecab-ipadic-neologd/decompressed_seed/neologd-adverb-dict-seed.20150623.csv";
open my $file_word, '<', $dir;
while(<$file_word>){
    my @word = split(',',$_);
    unless(defined($allWords{$word[0]})){
	$allWords{$word[0]} = 1;
    }
}
close $file_word;

######################Load Proxy IP Address##################################
my @proxyList;
open my $file_proxy, '<','good_proxy.txt';
while(<$file_proxy>){
    chomp($_);
    push @proxyList,$_;
}
close $file_proxy;


sub get_a_ProxyIP{
    my $id = int(rand($#proxyList+1));
    return $proxyList[$id];
}
######################Crawler ##############################################
my $countTotalDownloadWord = 0;
my %visitedUrls = ();

open my $file_log,'>','MyLogDuringCrawling.txt_2';
sub MyLog{
    my $string = shift;
    say $string;
    say $file_log $string;
}

open my $file_ans, '>', 'YomiTangoPairs.txt_2';
sub MyAnwser{
    my $string =shift;
#    say $string;
    say $file_ans $string;
}

open my $file_rawtext, '>','rawText.txt_2';
my @urls = (
    'http://2chmm.com',
    'https://ja.wikipedia.org/',
    );
sub start_work{
    while(scalar(@urls) > 0){
	last if($countTotalDownloadWord >= 100000);
	my $url = shift @urls;
	my $mech = WWW::Mechanize->new(timeout => 8);
	my $randomProxy = &get_a_ProxyIP();
	$mech->proxy('http',$randomProxy);
	eval{$mech->get($url);};
	if($@){
	    MyLog($@." error ".$randomProxy);
	    next;
	}
	MyLog($url);
	$visitedUrls{$url} = 1;
	foreach ($mech->links){
	    my $link = $_->url;
	    if($link =~ /https?/){
		next if(exists($visitedUrls{$link}));
		push @urls,$link;
	    }
	}
	my $text = decode_utf8($mech->content(format=>'text')); 
	if($text =~ /\x{3002}/){ #split text into sentences 
	    $text =~ s/\x{3002}/\x{3002}\t/g;
	}
	my @sents = split("\t",$text);
	foreach(@sents){
	    say $file_rawtext $_;
	    my $mecab = Text::MeCab->new;
	    my $n = $mecab->parse($_);
	    while($n = $n->next){
		if($n->feature){
		    next if(exists($allWords{$n->surface}));
		    $allWords{$n->surface} = 1;
		    $countTotalDownloadWord += 1;
		    my @features = split(",",$n->feature);
		    if($#features+1 <= 7){
			MyAnwser($n->surface."\t".$n->surface);
		    }else{
			MyAnwser($n->surface."\t".$features[7]);		    
		    }
		}
	    }
	}	
    }
    say "fininshed ".$countTotalDownloadWord ;
}
&start_work();
