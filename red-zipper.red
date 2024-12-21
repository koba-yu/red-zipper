Red  [
	Title:	"Sample Red implementation to decode zip file"
	Needs:	'view
	Author:	"Koba-yu"
	File:	%red-zipper.red
	Tabs:	4
]

; Open the file selection dialog and read the file as binary data.
b: read/binary file: request-file

fe-bins: parse b [collect [any [
			; [file entry]
			; Pick binaries from the beginning signature of the file entry #{504B0304} to just before the next file entry
			; or central directory signature #{504b0102} and set it on 'feb.
			; "keep" makes a block of 'feb values and returns it to 'fe-bins.
			thru #{504B0304} copy feb to [#{504B0304} | #{504b0102}] keep (feb)
			; [central directory]
			; Pick binaries from the beginning signature of the central directory to the ending signature of the central directory
			; and set it on 'cdi, and set binaries after the ending signature on 'eocd-bin.
			| thru #{504b0102} copy cdi thru #{504b0506} copy eocd-bin thru end
		]
	]
]

; The subsequent process divides the data in fixed size according to the ZIP specification.
; Defining the function to be used later.
util: context [
	take-to-int: func [
		; reverse a little-endian binary and then convert it to an integer by the given size.
		bin [binary!] size [integer!]
	][
		to-integer reverse take/part bin size
	]
	bits-to-int: func [
		; convert the binary bit string to integer value.
		bits [string!]
	][
		to-integer debase/base pad/left/with bits 8 #"0" 2
	]
]

; Keep the original data because the subsequent process is a destructive change.
; This is not a mandatory implementation but is done for clarity when debugging.
eocd-bin*: copy eocd-bin

; Set values on each field, according to the ZIP specification.
eocd: object [
	disk-num:			util/take-to-int eocd-bin* 2
	cdi-num:			util/take-to-int eocd-bin* 2
	total-num-disk:		util/take-to-int eocd-bin* 2
	total-num-cdi:		util/take-to-int eocd-bin* 2
	cdi-size:			util/take-to-int eocd-bin* 4
	offset-cdi:			util/take-to-int eocd-bin* 4
	zipcomment-length:	util/take-to-int eocd-bin* 2
]

; Add a field on the eocd object.
; eocd/zipcomment-length is required to make the zipcomment field. That's why I need to define the zipcomment field separately.
eocd: make eocd [
	zipcomment: if zipcomment: take/part eocd-bin* eocd/zipcomment-length [to-string zipcomment]
]

; Loop through values of 'fe-bins.
file-entries: collect [foreach feb fe-bins [

		; Keep the original data because the subsequent process is a destructive change.
		; This is not a mandatory implementation but is done for clarity when debugging.
		feb*: copy feb

		; Set values on each field, according to the ZIP specification.
		o: object [
			version-extract:	util/take-to-int feb* 2
			general-flag:		take/part feb* 2
			compression-method:	util/take-to-int feb* 2
		]

		seconds*: enbase/base reverse take/part feb* 2 2
		hours*: take/part seconds* 5
		minutes*: take/part seconds* 6 ; The remainder is second.

		hours: util/bits-to-int hours*
		minutes: util/bits-to-int minutes*
		seconds: (util/bits-to-int seconds*) * 2 ; ZIP holds 1/2 precision for seconds only. Therefore we need to double the value.

		day*: enbase/base reverse take/part feb* 2 2
		year*: take/part day* 7
		month*: take/part day* 4 ; The remainder is day.

		year: (util/bits-to-int year*) + 1980 ; The year field in the ZIP holds the number of years back based on 1980.
		month: util/bits-to-int month*
		day: util/bits-to-int day*

		; Add the last-modified time field on the current object and subsequent fields.
		o: make o [
			last-modified:		make date! reduce [day month year hours minutes seconds]
			crc-32:				enbase/base to-binary util/take-to-int feb* 4 16
			compressed-size:	util/take-to-int feb* 4
			uncompressed-size:	util/take-to-int feb* 4
			file-name-length:	util/take-to-int feb* 2
			extra-field-length:	util/take-to-int feb* 2
		]

		; Add a field on the eocd object.
		; The values of the field defined above are required to make these field. That's why I need to define these fields separately.
		keep make o [
			file-name:		to-string take/part feb* o/file-name-length
			extra-field: 	take/part feb* o/extra-field-length
			binary:			copy feb*
		]
	]
]

; Convert the object block to the file name block.
entries: collect [foreach file-entry file-entries [keep file-entry/file-name]]

; Make a view to display the processing results.
view compose [
	; Text of the file name that is read.
	text (rejoin ["Loaded zip file: " last split-path file]) return
	text "Contents of the zip" return

	; The list of entries. I set the values to the face 'content that is defined to show the contents of the ZIP.
	l: text-list data entries on-change [

		; Clear properties related to show the content.
		content/text: none
		content/image: none
		i: l/selected

		unless dir? to-red-file file-entries/:i/file-name [

			; If the compression-method is 8, the content is compressed by deflate so needed to decompress.
			; Otherwise, the binary is returned as-is.
			; So far, I implemented the code for non-compressed and deflate compressed.
			db: either file-entries/:i/compression-method = 8 [
				decompress file-entries/:i/binary 'deflate
			][
				file-entries/:i/binary
			]

			; Switch how to make the value by checking the extension of the file, so far.
			switch suffix? file-entries/:i/file-name [
				%.txt [content/text: to-string db]
				%.png [content/image: load/as db 'png]
			]
		]
	]

	; The face to show the content.
	content: base 300x300
]
