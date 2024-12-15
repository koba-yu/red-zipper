Red  [
	Title:	"Sample Red implementation to decode zip file"
	Needs:	'view
	Author:	"Koba-yu"
	File:	%red-zipper.red
	Tabs:	4
]

; ファイル選択ダイアログを表示し、選択されたファイルをバイナリデータとして読み込み
b: read/binary file: request-file

fe-bins: parse b [collect [any [
			; file entry
			; ファイルエントリの先頭 #{504B0304} から次のファイルエントリの直前またはセントラルディレクトリの直前 #{504b0102} の間を feb にセット
			; keepされた feb はblockになって fe-bins に返される
			thru #{504B0304} copy feb to [#{504B0304} | #{504b0102}] keep (feb)
			; central directory
			; セントラルディレクトリの先頭から終端レコードの開始位置 #{504b0506} までを cdi に、そこから末端までを eocd-bin にセット
			| thru #{504b0102} copy cdi thru #{504b0506} copy eocd-bin thru end
		]
	]
]

; 後続処理でZIP仕様に従って固定サイズで分割していく
; リトルエンディアンのバイナリなのでreverseしてからintegerにするための関数
le: context [take-to-int: func [bin [binary!] size [integer!]][to-integer reverse take/part bin size]]

; 後続処理が破壊的変更なので、元データは取っておく
; （これはやらなくても動きはする）
eocd-bin*: copy eocd-bin

; ZIPの仕様に従ってフィールドにセットしていく
eocd: object [
	disk-num:			le/take-to-int eocd-bin* 2
	cdi-num:			le/take-to-int eocd-bin* 2
	total-num-disk:		le/take-to-int eocd-bin* 2
	total-num-cdi:		le/take-to-int eocd-bin* 2
	cdi-size:			le/take-to-int eocd-bin* 4
	offset-cdi:			le/take-to-int eocd-bin* 4
	zipcomment-length:	le/take-to-int eocd-bin* 2
]

; 作成済みのオブジェクトにフィールド追加
; zipcomment-lengthを使わないといけないので、上とは別に処理している
eocd: make eocd [
	zipcomment: if zipcomment: take/part eocd-bin* eocd/zipcomment-length [to-string zipcomment]
]

; 取得した fe-bins をループ処理
file-entries: collect [foreach feb fe-bins [

		; 後続処理が破壊的変更なので、元データは取っておく
		; （これはやらなくても動きはする）
		feb*: copy feb

		; ZIPの仕様に従ってフィールドにセットしていく
		o: object [
			version-extract:	le/take-to-int feb* 2
			general-flag:		take/part feb* 2
			compression-method:	le/take-to-int feb* 2
			last-modified-time:	le/take-to-int feb* 2
			last-modified-date:	le/take-to-int feb* 2
			crc-32:				enbase/base to-binary le/take-to-int feb* 4 16
			compressed-size:	le/take-to-int feb* 4
			uncompressed-size:	le/take-to-int feb* 4
			file-name-length:	le/take-to-int feb* 2
			extra-field-length:	le/take-to-int feb* 2
		]

		; 作成済みのオブジェクトにフィールド追加
		; 作成済みのフィールドの値を使って処理しないといけないので、上とは別に処理している
		keep make o [
			file-name:		to-string take/part feb* o/file-name-length
			extra-field: 	take/part feb* o/extra-field-length
			binary:			copy feb*
		]
	]
]

; オブジェクトの block からファイル名の block に変換
entries: collect [foreach file-entry file-entries [keep file-entry/file-name]]

; 処理結果の表示用のViewを作成
view compose [
	; 読み込みしたZIPファイルのファイル名表示
	text (rejoin ["Loaded zip file: " last split-path file]) return
	text "Contents of the zip" return

	; エントリのリスト。選択時のイベントでコンテンツ表示用の face（content）の値をセットしている
	l: text-list data entries on-change [
		content/text: none
		content/image: none
		i: l/selected
		unless dir? to-red-file file-entries/:i/file-name [

			db: either file-entries/:i/compression-method = 8 [
				decompress file-entries/:i/binary 'deflate
			][
				file-entries/:i/binary
			]

			switch suffix? file-entries/:i/file-name [
				%.txt [content/text: to-string db]
				%.png [content/image: load/as db 'png]
			]
		]
	]
	; コンテンツ表示用のface
	content: base 300x300
]
