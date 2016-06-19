use 5.010;
#use strict;
#use warnings;
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

open my $file_log,'>','MyLogDuringCrawling.txt_3';
sub MyLog{
    my $string = shift;
    say $string;
    say $file_log $string;
}

open my $file_ans, '>', 'word2vec_wordList_1.txt';
sub MyAnwser{
    my $string =shift;
#    say $string;
    say $file_ans $string;
}

open my $file_rawtext, '>','word2vec_rawText_1.txt';
my @urls = (
    #'http://2chmm.com',
    'https://ja.wikipedia.org/',
    );

my $totalLinksTraversed = 0;
sub start_work{
    while(scalar(@urls) > 0){
	last if($countTotalDownloadWord >= 10000);
	my $url = shift @urls;
	my $totalLinksTraversed += 1;
	my $mech = WWW::Mechanize->new(timeout => 8);
	my $randomProxy = &get_a_ProxyIP();
	$mech->proxy('http',$randomProxy);
	eval{$mech->get($url);};
	if($@){
	    MyLog($@." error ".$randomProxy);
	    $mech = WWW::Mechanize->new(timeout => 8);
	    $mech->get($url);
	}
	MyLog($url);
	$visitedUrls{$url} = 1;
	foreach($mech->links){
	    my $link = $_->url;
	    if($link =~ /^\/wiki/){
		$link = "https://ja.wikipedia.org".$link;		
	    }
	    if($link =~ /https:\/\/ja\.wiki/){
		next if(exists($visitedUrls{$link}));
		push @urls,$link;
	    }
	}
	my $text = decode_utf8($mech->content(format=>'text')); 
	if($text =~ /\x{3002}/){ #split text into sentences 
	    $text =~ s/\x{3002}/\x{3002}\t/g;
	}
	my @sents = split("\t",$text);
	foreach my$sent(@sents){
	    my $mecab = Text::MeCab->new;
	    my $n = $mecab->parse($sent);
	    my @Noun_Complex = ();
	    my @raw_sents = ();
	    my $must = 0;
	    while($n = $n->next){
		next unless($n->feature);
		my @x = split(",",$n->feature);
		my $pos = $x[0];
		my $c1 = $x[1];
		my $c2 = $x[2];

		if(($pos eq "名詞" && $c1 eq "一般")                       ||
                   ($pos eq "名詞" && $c1 eq "サ変接続")                   ||
                   ($pos eq "名詞" && $c1 eq "接尾" && $c2 eq "一般")     ||
                   ($pos eq "名詞" && $c1 eq "接尾" && $c2 eq "サ変接続") ||
                   ($pos eq "名詞" && $c1 eq "固有名詞")                   ||
                   ($pos eq "記号" && $c1 eq "アルファベット")
                    )
                {
                    push @Noun_Complex, $n->surface;
                    $must = 0;
                    next;
                }
                elsif(($pos eq "名詞" && $c1 eq "形容動詞語幹")||($pos eq "名詞" && $c1 eq "ナイ形容詞語幹"))
                {
                    push @Noun_Complex, $n->surface;
                    $must = 1;
                    next;
                }
                elsif($pos eq "名詞" && $c1 eq "接尾" && $c2 eq "形容動詞語幹")
                {
                    push @Noun_Complex, $n->surface;
                    $must = 1;
                    next;
                }
                elsif($pos eq "動詞"){
                    @Noun_Complex = ();
                }
                else
                {
                    if($must == 0 && @Noun_Complex)
                    {
                        my $noun = join("",@Noun_Complex);
			next if($noun =~ /^[a-zA-Z0-9]+$/);
			next unless(exists($allWords{$noun}));
			delete($allWords{$noun});
			$countTotalDownloadWord += 1;
			MyAnwser($noun);		    		    
			push @raw_sents, $noun;
			while($n = $n->next){
			    push @raw_sents, $n->surface;
			}
			say $file_rawtext join(" ",@raw_sents);			
			last;
                    }
                }
                if($must){
                    @Noun_Complex = ();
                }
                $must = 0;
		push @raw_sents, $n->surface;
	    }
	}	
    }
    say "fininshed ".$countTotalDownloadWord ;
    say "total links traversed ! ".$totalLinksTraversed;
}
&start_work();
