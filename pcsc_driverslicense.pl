#!/usr/bin/perl
# pcsc test
use warnings;
use strict;
use utf8;
use Chipcard::PCSC;
use Chipcard::PCSC::Card;
use Encode;

my $hContext;
my $hCard;
my @ReadersList;
my $SendData;
my $RecvData;
# SCardControl with Control Code SCARD_CTL_CODE(3500) 0x42000000|DAC(3500).
my $control_code = 0x42000dac;
my @data;
my $tmpVal;

$hContext = new Chipcard::PCSC();
die ("Can't create the PCSC object: $Chipcard::PCSC::errno\n") unless (defined $hContext);
 
@ReadersList = $hContext->ListReaders();
die ("Can't get readers' list: $Chipcard::PCSC::errno\n") unless (defined($ReadersList[0]));
 
#$, = "\n  ";
#print @ReadersList . "\n";
#
my (@readers_states, $reader_state, $timeout, $event_state);
# create the list or readers to watch
map { push @readers_states, ({'reader_name'=>"$_"}) } @ReadersList;
 
my @StatusResult = $hContext->GetStatusChange( \@readers_states);

#print @StatusResult . "\n";
print $readers_states[0]{'reader_name'}."\n";
#print "ATR: ". Chipcard::PCSC::array_to_ascii($readers_states[0]{'ATR'})."\n";

$hCard = new Chipcard::PCSC::Card ($hContext);

## カード読み込む
## 他の処理がリーダーを使用するのを許可する
## プロトコルT0, T1, Raw
$hCard->Connect($ReadersList[0],$Chipcard::PCSC::SCARD_SHARE_SHARED,$Chipcard::PCSC::SCARD_PROTOCOL_T0|$Chipcard::PCSC::SCARD_PROTOCOL_T1|$Chipcard::PCSC::SCARD_PROTOCOL_RAW);

my $tmpdata = '';

my $select_mf = '00 A4 00 00';
my $select_df = '00 A4 04 0C 10';
my $select_ef = '00 A4 02 0C 02';
my $VerifyPIN = '00 20 00 80 04';
# 00 20 00 80(P2:固定+カレントEF) 04(LC:PINの長さ)
my $ReadBinary = '00 B0 00 00 00 00 00';
my $VerifyCount = "00 20 00 80";

my $mfef01 = '2F 01';    # 共通データ
my $mfief01 = '00 01';   # PIN1
my $PIN1 = '';
my $mfief02 = '00 02';   # PIN2
my $PIN2 = '';
my $df1 = 'A0 00 00 02 31 01 00 00 00 00 00 00 00 00 00 00';
my $df1ef01 = '00 01';   # 
my $df1ef02 = '00 02';
my $df2 = 'A0 00 00 02 31 02 00 00 00 00 00 00 00 00 00 00';
my $df2ef01 = '00 01';
#3(2)カ(ア)参照
#カ 暗証番号、アクセス権限
#(ｱ)  暗証番号１(PIN 1)
#格納ファイル名: MF/IEF01
#ａ PIN 1は4桁の数字(JIS X 0201)とする。
#ｂ 試行許容回数を超過した場合、PIN 1を閉塞処理すること。試行許容回数は３回とする。
#ｃ 閉塞解除権限は各都道府県公安委員会の権限とする。詳細は別紙３で定める。
#ｄ 交付後のPIN変更機能は実装しないこと。
#ｅ MF/EF02の値フィールドVのb1を０とした場合は****(DPIN)を、１とした場合は免許保有者の希望する４桁の数字を記録すること。
#*(ASTERISK)=“2A”(JIS X 0201)

## passport 

# MF選択
$tmpdata = $select_mf;
transmit_code($hCard,$tmpdata,0);

# MF/EF01(共通データ)選択
$tmpdata = $select_ef.' '.$mfef01;
transmit_code($hCard,$tmpdata,0);

$tmpdata = $ReadBinary;
transmit_code($hCard,$tmpdata,0);

# MF選択
$tmpdata = $select_mf;
transmit_code($hCard,$tmpdata,0);

# MF/IEF01(PIN01)選択
$tmpdata = $select_ef. ' '.$mfief01;
transmit_code($hCard,$tmpdata,0);

# 照合回数の確認
$tmpdata = $VerifyCount;
transmit_code($hCard,$tmpdata,1);

# PIN1の入力
&check_before_verifyPINcode($hCard,"PIN1");
$PIN1 = join(" ", input_pincode("PIN1"));

# PIN01の照合
#$tmpdata = $VerifyPIN. ' '.join(" ",unpack("H2H2H2H2",$PIN1));
$tmpdata = $VerifyPIN. ' '.$PIN1;
transmit_code($hCard,$tmpdata,0);
$tmpdata = $VerifyCount;
transmit_code($hCard,$tmpdata,1);

# MF/IEF02(PIN02)選択
$tmpdata = $select_ef. ' '.$mfief02;
transmit_code($hCard,$tmpdata,0);

# 照合回数の確認
$tmpdata = $VerifyCount;
transmit_code($hCard,$tmpdata,1);

# PIN2の入力
&check_before_verifyPINcode($hCard,"PIN2");
$PIN2 = join(" ", input_pincode("PIN2"));

# PIN02の照合
$tmpdata = $VerifyPIN. ' '.$PIN2;
transmit_code($hCard,$tmpdata,0);
$tmpdata = $VerifyCount;
transmit_code($hCard,$tmpdata,1);

# df1を選択
$tmpdata = $select_df.' '.$df1;
transmit_code($hCard,$tmpdata,0);

# df1/ef01を選択
$tmpdata = $select_ef.' '.$df1ef01;
transmit_code($hCard,$tmpdata,0);

# 読み出し
$tmpdata = $ReadBinary;
transmit_code_str($hCard,$tmpdata,17);

# df1/ef02を選択
$tmpdata = $select_ef.' '.$df1ef02;
transmit_code($hCard,$tmpdata,0);

# 読み出し
$tmpdata = $ReadBinary;
transmit_code_str($hCard,$tmpdata,65);

# 写真の読み出し
# df2を選択
$tmpdata = $select_df.' '.$df2;
transmit_code($hCard,$tmpdata,0);

# df2/ef01を選択
$tmpdata = $select_ef.' '.$df2ef01;
transmit_code($hCard,$tmpdata,0);

# 読み出し
$tmpdata = $ReadBinary;
$RecvData = transmit_code($hCard,$tmpdata,2);
output_picture($RecvData);


$hCard->Disconnect();
# メインの処理はここまで

# 写真の出力
sub output_picture{
	# 引数受け渡し
	my($recv)=shift @_;
	#foreach my $tmp (@{$recv}) {
	#	printf ("%02X ", $tmp);
	#} print "\n";
	
	# 先頭データで余分なByteを除く
	# タグフィールド DF2/EF01なので2Byte構成
	# P.2-9セ　写真 タグ"5F40"
	shift(@{$recv}); # 5F
	shift(@{$recv}); # 40
	# 長さフィールド P.2-3
	# 第1Byte
	shift(@{$recv}); # 82
	# 第2-3Byteで値フィールドの長さを指定
	my $maxcount = shift(@{$recv});
	$maxcount <<= 8;
	$maxcount += shift(@{$recv});
	#print $maxcount."\n";
	
	# 出力先のファイルを開く
	# JPEG2000なので.jp2
	open (IMG, ">./picture.jp2") or die;
	binmode IMG;
	my $n = 0;
	foreach (@{$recv}){
		if($n>$maxcount){
			last;
		}
		printf IMG ("%c" ,$_);
		$n+=1;
	}close(IMG);
}

# PIN CODEの入力
sub input_pincode{
	# 引数受け渡し
	# 引数は表示に使用するだけ
	my($message)=shift @_;
	print "input $message(4 numbers): ";
	# 標準入力待ち
	while(<STDIN>){
		chomp($_);
		# 入力が数字4digit以外は入力待ちに戻る
		if($_ =~ /^\d{4}$/){
			last;
		}else{
			print '>';
		}
	}
	# 数字を一文字ずつ分解して配列に入れる
	my @arr = split (//,$_);
	# 配列内の数字をHEX2文字に変換
	@arr =map(unpack("H2",$_), @arr);
	#foreach (@arr){
	#	print $_." ";
	#}print "\n";
	return @arr;
}

# PIN CODE認証の前に認証するか確認するルーチン
sub check_before_verifyPINcode{
	# 引数受け渡し
	# 認証しない場合は終了するのでcard Objectを受け取る
	my ($card) =shift @_;
	# メッセージに使用する
	my ($message) = shift @_;
	
	print "Next step is Verify$message. Continue? [y/n] ";
	# 標準入力待ち
	while(<STDIN>){
		chomp($_);
		# yの場合、次の処理へ移る
		if ($_ eq 'y'){
			last;
		}elsif($_ eq 'n'){
			# nの場合、終了する
			print "Disconnect.\n";
			$card->Disconnect();
			exit;
		}else{
			# それ以外の場合、入力待ちに戻る
			print ">";
		}
	}
}

# 指定したコードをカードに送信するルーチン
sub transmit_code
{
	# 引数受け渡し
	# 送信対象のカード
	my($card) = shift @_;
	# 送信するコード
	my($code) = shift;
	# 受信コードを表示するかのフラグ
	my($flg) = shift;
	
	my $sw;
	my $recv;
	my $tmp;
	
	# コードを送信
	#($sw,$recv) = $card->TransmitWithCheck($code, "6E 00", 1);
	$recv = $card->Transmit(Chipcard::PCSC::ascii_to_array($code));
	# flgがonなら受信コードを表示する
	if($flg==1){
		#warn "TransmitWithCheck: $Chipcard::PCSC::Card::Error" unless defined $sw;
		#print Chipcard::PCSC::array_to_ascii($recv)."\n";
		foreach $tmp (@{$recv}) {
			printf ("%02X ", $tmp);
		} print "\n";
	}
	
	# 戻り値は受信コード
	return ($recv);
}
sub change_code_readable
{
	my ($recv)=shift;
	my $tmp;
	my $count = 0;
	my $maxcount = 0;
	my @tag = ();
	my @data = ();
	
	foreach (@{$recv}){
		$maxcount++;
	}
	
	my $i;
	my $j;
	for($i = 0;$i < $maxcount;$i++){
		$tmp = shift(@{$recv});
		$count = shift(@{$recv});
		if($count == 255){
			#foreach my $a (@data){
			#	if(defined $a){print"$a\n";}
			#}
			last;
		}$tag[$i] = $tmp;
		if($tmp==0x21){
			for($j=0;$j<$count;$j++){
				$data[$tag[$i]].=chr(shift(@{$recv}));
			}
			#print "$data[$tag[$i]]\n";
			next;
		}
		$tmp ='';
		if($count >2){
			if($count%2 == 0){
				for($j=0;$j<$count;$j+=2){
					$tmp = chr(shift(@{$recv})).chr(shift(@{$recv}));
					$data[$tag[$i]] .= Encode::encode('utf8',Encode::decode('jis0208-raw',$tmp));
#					$data[$tag[$i]] .= Encode::from_to($tmp,'jis0208-raw','utf8');
					$tmp='';
				}#print "$data[$tag[$i]]\n";
			}else{
				for($j=0;$j<$count;$j++){
					$tmp = chr(shift(@{$recv}));
					if($j==0){
						if($tmp%48==3){
							$data[$tag[$i]] .=Encode::encode('utf-8',"昭和");
						}elsif($tmp%48==4){
							$data[$tag[$i]] .=Encode::encode('utf-8',"平成");
						}
					}else{
						$data[$tag[$i]] .= $tmp;
					}
				}#print "$data[$tag[$i]]\n";
			}
		}elsif($count==1){
			$data[$tag[$i]]=shift(@{$recv});
		}elsif($count==0){
			$data[$tag[$i]]=0;
		}else{}
		$i+=$count;
	}
	my $tag_ref = \@tag;
	my $data_ref = \@data;
	return ($tag_ref,$data_ref);
}

# コードを送信して受信したコードを表示するルーチン
sub transmit_code_str
{
	# 引数受け渡し
	# card Object
	my($card) = shift @_;
	# 送信コード
	my($code) = shift;
	# 表示するデータのタグ 0x11 or 0x41
	my $tag = shift;
	
	my $sw;
	my $recv;
	
	#($sw,$recv) = $card->TransmitWithCheck($code, "6E 00", 1);
	#warn "TransmitWithCheck: $Chipcard::PCSC::Card::Error" unless defined $sw;
	
	# コードを送信して受信コードを受け取る
	$recv = $card->Transmit(Chipcard::PCSC::ascii_to_array($code));
	#print Chipcard::PCSC::array_to_ascii($recv)."\n";
	
	# 表示するデータのタグと内容を初期化
	my @tagdata = &init_tag_data($tag);
	# 受信コードを可読可能な文字に変換
	my ($num,$data)=change_code_readable($recv);
	# データを表示する
	foreach my $tmp (@{$num}){
		if(defined $tmp){
			print Encode::encode('utf8',$tagdata[$tmp])."\t";
			print Encode::encode('utf8',Encode::decode('utf8',${$data}[$tmp]))."\n";
		}
	}
}

# DF1/EF01 のタグ内容を格納した配列を返すルーチン
sub init_tag_data{
	# 引数受け渡し
	# タグを指定 0x11 or 0x41 P.2-6 2-7
	my $tag_num = shift;
	my (@tag)=();
	if($tag_num == 0x11){
	$tag[0x11]='JIS制定年番号';
	$tag[0x12]='氏名';
	$tag[0x13]='呼び名';
	$tag[0x14]='通称名';
	$tag[0x15]='統一氏名';
	$tag[0x16]='生年月日';
	$tag[0x17]='住所';
	$tag[0x18]='交付年月日';
	$tag[0x19]='照合番号';
	$tag[0x1A]='免許証の色区分';
	$tag[0x1B]='有効期間の末日';
	$tag[0x1C]='免許の条件1';
	$tag[0x1D]='免許の条件2';
	$tag[0x1E]='免許の条件3';
	$tag[0x1F]='免許の条件4';
	$tag[0x20]='公安委員会名';
	$tag[0x21]='免許証の番号';
	$tag[0x22]='免許の年月日(二・小・原)';
	$tag[0x23]='免許の年月日(他)';
	$tag[0x24]='免許の年月日(二種)';
	$tag[0x25]='免許の年月日(大型)';
	$tag[0x26]='免許の年月日(普通)';
	$tag[0x27]='免許の年月日(大特)';
	$tag[0x28]='免許の年月日(大自二)';
	$tag[0x29]='免許の年月日(普自二)';
	$tag[0x2A]='免許の年月日(小特)';
	$tag[0x2B]='免許の年月日(原付)';
	$tag[0x2C]='免許の年月日(け引)';
	$tag[0x2D]='免許の年月日(大二)';
	$tag[0x2E]='免許の年月日(普二)';
	$tag[0x2F]='免許の年月日(大特二)';
	$tag[0x30]='免許の年月日(け引二)';
	$tag[0x31]='免許の年月日(中型)';
	$tag[0x32]='免許の年月日(中二)';
	$tag[0x33]='免許の年月日(準中型)';
	}elsif($tag_num==0x41){
	$tag[0x41]='本籍';
	}
	
	# タグ内容配列を返す
	return (@tag);
}