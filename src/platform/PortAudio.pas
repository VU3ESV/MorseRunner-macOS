//------------------------------------------------------------------------------
// Minimal Free Pascal binding to the PortAudio v19 C library (libportaudio).
//
// This is NOT part of the original MorseRunner source. It exists only to give
// the macOS port a cross-platform audio device, replacing the Windows
// waveOut/MMSystem calls that the original SndCustm.pas / SndOut.pas used.
//
// Only the handful of entry points that platform/SndOut.pas needs are declared.
// Install the library with:  brew install portaudio
//------------------------------------------------------------------------------
unit PortAudio;

{$MODE ObjFPC}{$H+}

interface

{$IFDEF DARWIN}
  {$LINKLIB portaudio}
{$ENDIF}

uses
  ctypes;

const
{$IFDEF DARWIN}
  LIB_PORTAUDIO = 'portaudio';
{$ELSE}
  {$IFDEF WINDOWS}
  LIB_PORTAUDIO = 'portaudio_x64';
  {$ELSE}
  LIB_PORTAUDIO = 'portaudio';
  {$ENDIF}
{$ENDIF}

type
  PaError        = cint32;
  PaDeviceIndex  = cint32;
  PaSampleFormat = culong;
  PaStreamFlags  = culong;
  PaStreamCallbackFlags = culong;
  PPaStream      = pointer;

  PPaStreamCallbackTimeInfo = pointer;  // opaque; not used by this port

  // PortAudio callback return codes
  // paContinue = 0, paComplete = 1, paAbort = 2

const
  paNoError    = 0;

  paFloat32    = PaSampleFormat($00000001);
  paInt16      = PaSampleFormat($00000008);

  paContinue   = 0;
  paComplete   = 1;
  paAbort      = 2;

  // Let PortAudio choose an optimal (and possibly changing) host buffer size:
  paFramesPerBufferUnspecified = 0;

type
  // int callback(const void* input, void* output, unsigned long frameCount,
  //              const PaStreamCallbackTimeInfo* timeInfo,
  //              PaStreamCallbackFlags statusFlags, void* userData)
  TPaStreamCallback = function(input: pointer; output: pointer;
    frameCount: culong; timeInfo: PPaStreamCallbackTimeInfo;
    statusFlags: PaStreamCallbackFlags; userData: pointer): cint32; cdecl;

function Pa_Initialize: PaError; cdecl; external LIB_PORTAUDIO;
function Pa_Terminate: PaError; cdecl; external LIB_PORTAUDIO;

function Pa_OpenDefaultStream(var stream: PPaStream;
  numInputChannels, numOutputChannels: cint32;
  sampleFormat: PaSampleFormat; sampleRate: cdouble;
  framesPerBuffer: culong; streamCallback: TPaStreamCallback;
  userData: pointer): PaError; cdecl; external LIB_PORTAUDIO;

function Pa_StartStream(stream: PPaStream): PaError; cdecl; external LIB_PORTAUDIO;
function Pa_StopStream(stream: PPaStream): PaError; cdecl; external LIB_PORTAUDIO;
function Pa_AbortStream(stream: PPaStream): PaError; cdecl; external LIB_PORTAUDIO;
function Pa_CloseStream(stream: PPaStream): PaError; cdecl; external LIB_PORTAUDIO;

function Pa_GetErrorText(errorCode: PaError): pchar; cdecl; external LIB_PORTAUDIO;

implementation

end.
