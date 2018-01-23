/******************************************************************************
 * Spine Runtimes Software License v2.5
 *
 * Copyright (c) 2013-2016, Esoteric Software
 * All rights reserved.
 *
 * You are granted a perpetual, non-exclusive, non-sublicensable, and
 * non-transferable license to use, install, execute, and perform the Spine
 * Runtimes software and derivative works solely for personal or internal
 * use. Without the written permission of Esoteric Software (see Section 2 of
 * the Spine Software License Agreement), you may not (a) modify, translate,
 * adapt, or develop new applications using the Spine Runtimes or otherwise
 * create derivative works or improvements of the Spine Runtimes or (b) remove,
 * delete, alter, or obscure any trademarks or any copyright, trademark, patent,
 * or other intellectual property or proprietary rights notices on or in the
 * Software, including any copy thereof. Redistributions in binary or source
 * form must include this license and terms.
 *
 * THIS SOFTWARE IS PROVIDED BY ESOTERIC SOFTWARE "AS IS" AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL ESOTERIC SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES, BUSINESS INTERRUPTION, OR LOSS OF
 * USE, DATA, OR PROFITS) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 * IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *****************************************************************************/

package spine.animation {
	import spine.attachments.Attachment;
	import spine.attachments.VertexAttachment;
	import spine.Event;
	import spine.Skeleton;
	import spine.Slot;

	public class DeformTimeline extends CurveTimeline {		
		public var slotIndex : int;
		public var frames : Vector.<Number>;
		public var frameVertices : Vector.<Vector.<Number>>;
		public var attachment : VertexAttachment;

		public function DeformTimeline(frameCount : int) {
			super(frameCount);
			frames = new Vector.<Number>(frameCount, true);
			frameVertices = new Vector.<Vector.<Number>>(frameCount, true);
		}

		override public function getPropertyId() : int {
			return (TimelineType.deform.ordinal << 27) + attachment.id + slotIndex;
		}

		/** Sets the time and value of the specified keyframe. */
		public function setFrame(frameIndex : int, time : Number, vertices : Vector.<Number>) : void {
			frames[frameIndex] = time;
			frameVertices[frameIndex] = vertices;
		}

		override public function apply(skeleton : Skeleton, lastTime : Number, time : Number, firedEvents : Vector.<Event>, alpha : Number, blend : MixBlend, direction : MixDirection) : void {
			var vertexAttachment : VertexAttachment;
			var setupVertices : Vector.<Number>;
			var slot : Slot = skeleton.slots[slotIndex];
			var slotAttachment : Attachment = slot.attachment;
			if (!(slotAttachment is VertexAttachment) || !(VertexAttachment(slotAttachment)).applyDeform(attachment)) return;
			
			var verticesArray : Vector.<Number> = slot.attachmentVertices;
			if (verticesArray.length == 0) blend = MixBlend.setup;
			
			var frameVertices : Vector.<Vector.<Number>> = this.frameVertices;
			var vertexCount : int = frameVertices[0].length;
			var vertices : Vector.<Number>;		

			var frames : Vector.<Number> = this.frames;
			var i : int;			
			if (time < frames[0]) {
				vertexAttachment = VertexAttachment(slotAttachment);
				switch (blend) {
				case MixBlend.setup:
					verticesArray.length = 0;
					return;
				case MixBlend.first:
					if (alpha == 1) {
						verticesArray.length = 0;
						return;
					}
					verticesArray.length = vertexCount;
					vertices = verticesArray;
					if (vertexAttachment.bones == null) {
						// Unweighted vertex positions.
						setupVertices = vertexAttachment.vertices;
						for (i = 0; i < vertexCount; i++)
							vertices[i] += (setupVertices[i] - vertices[i]) * alpha;
					} else {
						// Weighted deform offsets.
						alpha = 1 - alpha;
						for (i = 0; i < vertexCount; i++)
							vertices[i] *= alpha;
					}
				}
				return;
			}						

			verticesArray.length = vertexCount;
			vertices = verticesArray;
			var n : int;			
			var setup : Number, prev : Number;
			if (time >= frames[frames.length - 1]) { // Time is after last frame.
				var lastVertices : Vector.<Number> = frameVertices[frames.length - 1];
				if (alpha == 1) {
					if (blend == MixBlend.add) {
						vertexAttachment = VertexAttachment(slotAttachment);
						if (vertexAttachment.bones == null) {							
							setupVertices = vertexAttachment.vertices;
							for (i = 0; i < vertexCount; i++) {								
								vertices[i] += lastVertices[i] - setupVertices[i];
							}
						} else {							
							for (i = 0; i < vertexCount; i++)
								vertices[i] += lastVertices[i];
						}
					} else {						
						for (i = 0, n = vertexCount; i < n; i++)
							vertices[i] = lastVertices[i];
					}
				} else {
					switch (blend) {
						case MixBlend.setup:
							vertexAttachment = VertexAttachment(slotAttachment);
							if (vertexAttachment.bones == null) {
								// Unweighted vertex positions, with alpha.
								setupVertices = vertexAttachment.vertices;
								for (i = 0; i < vertexCount; i++) {
									setup = setupVertices[i];
									vertices[i] = setup + (lastVertices[i] - setup) * alpha;
								}
							} else {
								// Weighted deform offsets, with alpha.
								for (i = 0; i < vertexCount; i++)
									vertices[i] = lastVertices[i] * alpha;
							}
							break;
						case MixBlend.first:
						case MixBlend.replace:
							for (i = 0; i < vertexCount; i++)
								vertices[i] += (lastVertices[i] - vertices[i]) * alpha;
						case MixBlend.add:
							vertexAttachment = VertexAttachment(slotAttachment);
							if (vertexAttachment.bones == null) {								
								setupVertices = vertexAttachment.vertices;
								for (i = 0; i < vertexCount; i++) {									
									vertices[i] += (lastVertices[i] - setupVertices[i]) * alpha;
								}
							} else {
								for (i = 0; i < vertexCount; i++)
									vertices[i] += lastVertices[i] * alpha;
							}							
					}					
				}
				return;
			}

			// Interpolate between the previous frame and the current frame.
			var frame : int = Animation.binarySearch1(frames, time);
			var prevVertices : Vector.<Number> = frameVertices[frame - 1];
			var nextVertices : Vector.<Number> = frameVertices[frame];
			var frameTime : Number = frames[frame];
			var percent : Number = getCurvePercent(frame - 1, 1 - (time - frameTime) / (frames[frame - 1] - frameTime));

			if (alpha == 1) {
				if (blend == MixBlend.add) {
					vertexAttachment = VertexAttachment(slotAttachment);
					if (vertexAttachment.bones == null) {						
						setupVertices = vertexAttachment.vertices;
						for (i = 0; i < vertexCount; i++) {
							prev = prevVertices[i];
							vertices[i] += prev + (nextVertices[i] - prev) * percent - setupVertices[i];
						}
					} else {						
						for (i = 0; i < vertexCount; i++) {
							prev = prevVertices[i];					
							vertices[i] += prev + (nextVertices[i] - prev) * percent;
						}
					}
				} else {					
					for (i = 0; i < vertexCount; i++) {						
						prev = prevVertices[i];
						vertices[i] = prev + (nextVertices[i] - prev) * percent;
					}
				}
			} else {
				switch (blend) {
					case MixBlend.setup:
						vertexAttachment = VertexAttachment(slotAttachment);
						if (vertexAttachment.bones == null) {
							// Unweighted vertex positions, with alpha.
							setupVertices = vertexAttachment.vertices;
							for (i = 0; i < vertexCount; i++) {
								prev = prevVertices[i], setup = setupVertices[i];
								vertices[i] = setup + (prev + (nextVertices[i] - prev) * percent - setup) * alpha;
							}
						} else {
							// Weighted deform offsets, with alpha.
							for (i = 0; i < vertexCount; i++) {
								prev = prevVertices[i];
								vertices[i] = (prev + (nextVertices[i] - prev) * percent) * alpha;
							}
						}
						break;
					case MixBlend.first:
					case MixBlend.replace:
						for (i = 0; i < vertexCount; i++) {
							prev = prevVertices[i];
							vertices[i] += (prev + (nextVertices[i] - prev) * percent - vertices[i]) * alpha;
						}
						break;
					case MixBlend.add:
						vertexAttachment = VertexAttachment(slotAttachment);
						if (vertexAttachment.bones == null) {							
							setupVertices = vertexAttachment.vertices;
							for (i = 0; i < vertexCount; i++) {
								prev = prevVertices[i], setup = setupVertices[i];
								vertices[i] += (prev + (nextVertices[i] - prev) * percent - setupVertices[i]) * alpha;
							}
						} else {							
							for (i = 0; i < vertexCount; i++) {
								prev = prevVertices[i];
								vertices[i] += (prev + (nextVertices[i] - prev) * percent) * alpha;
							}
						}
				}				
			}
		}
	}
}