import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum Rating { Safe, Questionable, Explicit }

class InvalidRatingException implements Exception {
  final String _providedRating;

  InvalidRatingException(this._providedRating);

  String errorMessage() {
    return 'Got unexpected rating value: $_providedRating';
  }
}

Rating parseRating(String rating) {
  switch (rating) {
    case 's':
      return Rating.Safe;
    case 'q':
      return Rating.Questionable;
    case 'e':
      return Rating.Explicit;
  }

  throw InvalidRatingException(rating);
}

class PostResponse {
  final List<Post> posts;

  PostResponse(this.posts);

  factory PostResponse.fromJson(Map<String, dynamic> json) {
    List<Post> posts;

    if (json.containsKey('post')) {
      posts = [Post.fromJson(json['post'])];
    } else {
      posts = json['posts'].map<Post>((post) => Post.fromJson(post)).toList();
    }

    return PostResponse(posts);
  }
}

class Post {
  final int id;
  final String createdAt;
  final Rating rating;
  final PostFile file;
  final PostSample sample;
  final PostPreview preview;
  final List<Tag> tags;

  Post(this.id, this.createdAt, this.rating, this.file, this.sample,
      this.preview, this.tags);

  factory Post.fromJson(Map<String, dynamic> json) {
    final PostFile file = PostFile.fromJson(json['file']);
    assert(file != null);

    final PostSample sample = PostSample.fromJson(json['sample']);
    assert(sample != null);

    final PostPreview preview = PostPreview.fromJson(json['preview']);
    assert(preview != null);

    List<Tag> tags = List();

    json['tags'].forEach((name, tagItems) {
      final tagType = parseTagType(name);
      tagItems.forEach((tagValue) {
        final tag = Tag(tagValue, tagType);
        tags.add(tag);
      });
    });

    return Post(json['id'], json['created_at'], parseRating(json['rating']),
        file, sample, preview, tags);
  }

  String get bestPreviewURL {
    if (sample == null || sample.url == null) {
      return preview.url;
    }

    return sample.url;
  }

  List<String> get artists {
    return tags.isEmpty
        ? ["unknown"]
        : tags
            .where((tag) => tag.type == TagType.Artist)
            .map((tag) => tag.name)
            .toList();
  }
}

class PostFile {
  final int width;
  final int height;
  final String ext;
  final int size;
  final String md5;
  final String url;

  PostFile(this.width, this.height, this.ext, this.size, this.md5, this.url);
  PostFile.fromJson(Map<String, dynamic> json)
      : width = json['width'],
        height = json['height'],
        ext = json['ext'],
        size = json['size'],
        md5 = json['md5'],
        url = json['url'];
}

class PostSample {
  final bool has;
  final int height;
  final int width;
  final String url;

  PostSample(this.has, this.height, this.width, this.url);
  PostSample.fromJson(Map<String, dynamic> json)
      : has = json['has'],
        height = json['height'],
        width = json['width'],
        url = json['url'];
}

class PostPreview {
  final int width;
  final int height;
  final String url;

  PostPreview(this.width, this.height, this.url);
  PostPreview.fromJson(Map<String, dynamic> json)
      : width = json['width'],
        height = json['height'],
        url = json['url'];
}

enum TagType {
  General,
  Species,
  Character,
  Copyright,
  Artist,
  Invalid,
  Lore,
  Meta
}

class InvalidTagTypeException implements Exception {
  final String providedType;

  InvalidTagTypeException(this.providedType);

  String errorMessage() {
    return 'Unknown provided type: $providedType';
  }
}

TagType parseTagType(String tagType) {
  switch (tagType) {
    case 'general':
      return TagType.General;
    case 'species':
      return TagType.Species;
    case 'character':
      return TagType.Character;
    case 'copyright':
      return TagType.Copyright;
    case 'artist':
      return TagType.Artist;
    case 'invalid':
      return TagType.Invalid;
    case 'lore':
      return TagType.Lore;
    case 'meta':
      return TagType.Meta;
  }

  throw InvalidTagTypeException(tagType);
}

class Tag {
  final String name;
  final TagType type;

  Tag(this.name, this.type);
}

class ApiFailureException implements Exception {
  final int statusCode;

  ApiFailureException(this.statusCode);

  String errorMessage() {
    return 'Got invalid status code from API response: $statusCode';
  }
}

Future<PostResponse> fetchPosts() async {
  final resp = await http.get('https://e621.net/posts.json');

  if (resp.statusCode == 200) {
    return PostResponse.fromJson(json.decode(resp.body));
  } else {
    throw ApiFailureException(resp.statusCode);
  }
}
