red  [
	Title:   "Sample Red implementation to decode zip file"
	Author:  "Koba-yu"
	File: 	 %red-zipper.red
	Tabs:	 4
]

b: read/binary file: request-file

fe-bins: parse b [collect [any [
			; file entry
			thru #{504B0304} copy feb to [#{504B0304} | #{504b0102}] keep (feb)
			; central directory
			| thru #{504b0102} copy cdi thru #{504b0506} copy eocd-bin thru end
		]
	]
]

; 後続処理でZIP仕様に従って固定サイズで分割していく
; リトルエンディアンのバイナリなのでreverseしてからintegerにするための関数
le: context [take-to-int: func [bin [binary!] size [integer!]][to-integer reverse take/part bin size]]

eocd-bin*: copy eocd-bin
eocd: object [
	disk-num:			le/take-to-int eocd-bin* 2
	cdi-num:			le/take-to-int eocd-bin* 2
	total-num-disk:		le/take-to-int eocd-bin* 2
	total-num-cdi:		le/take-to-int eocd-bin* 2
	cdi-size:			le/take-to-int eocd-bin* 4
	offset-cdi:			le/take-to-int eocd-bin* 4
	zipcomment-length:	le/take-to-int eocd-bin* 2
]
eocd: make eocd [
	zipcomment: if zipcomment: take/part eocd-bin* eocd/zipcomment-length [to-string zipcomment]
]

file-entries: collect [foreach feb fe-bins [
		feb*: copy feb
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
		keep make o [
			file-name:		to-string take/part feb* o/file-name-length
			extra-field: 	take/part feb* o/extra-field-length
			binary:			copy feb*
		]
	]
]

entries: collect [foreach file-entry file-entries [keep file-entry/file-name]]

view compose [
	text (rejoin ["Loaded zip file: " last split form file "/"]) return
	text "Contents of the zip" return
	l: text-list data entries on-change [
		content/text: none
		content/image: none
		i: l/selected
		unless dir? to-red-file file-entries/:i/file-name [
			switch suffix? file-entries/:i/file-name [
				%.txt [
					content/image:
					content/text: to-string file-entries/:i/binary
				]
				%.png [
					content/image: load/as file-entries/:i/binary 'png
				]
			]
		]
	]
	content: base 300x300
]
