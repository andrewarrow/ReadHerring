# ReadHerring

An iOS app that extracts text from PDF files using PDFKit, with OCR fallback for scanned documents.

## Features

- Select PDF files from the device's file system
- Extract text using PDFKit's built-in text extraction
- Fall back to OCR when text cannot be extracted directly
- Display progress during PDF processing
- Show the first 1000 characters of extracted text

## Requirements

- iOS 14.0+
- Xcode 12.0+
- Swift 5.0+

## Dependencies

- PDFKit: Built-in framework for PDF handling
- Vision: Built-in framework for OCR text recognition

## Usage

1. Tap "Select PDF"
2. Choose a PDF file from your device
3. Wait for the processing to complete (progress bar will be shown)
4. View the extracted text
